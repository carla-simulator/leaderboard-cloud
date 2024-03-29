#!/bin/bash

#######################
## DEFAULT VARIABLES ##
#######################
export SCENARIO_RUNNER_ROOT="/utils/scenario_runner"
export LEADERBOARD_ROOT="/utils/leaderboard"
export PYTHONPATH="${SCENARIO_RUNNER_ROOT}":"${LEADERBOARD_ROOT}":${PYTHONPATH}

LOGCOPY_LOGS="/logs/logcopy/logcopy.log"
LOGCOPY_DONE_FILE="/logs/containers-status/logcopy.done"
SIMULATION_CANCEL_FILE="/logs/containers-status/simulation.cancel"
AGENT_RESULTS_FILE="/logs/agent/agent_results.json"
EVALAI_RESULTS_FILE="/logs/evalai/results.json"
EVALAI_STDOUT_FILE="/logs/evalai/stdout.txt"
EVALAI_METADATA_FILE="/logs/evalai/metadata.json"

###########
## UTILS ##
###########
update_database() {
  START_TIME=$(date +"%Y-%m-%d %T %Z")
  aws dynamodb update-item \
    --table-name "$DYNAMODB_SUBMISSIONS_TABLE" \
    --key '{"team_id": {"S": "'"${TEAM_ID}"'" }, "submission_id": {"S": "'"${SUBMISSION_ID}"'"} }' \
    --update-expression "SET submission_status = :s, results = :r, start_time = :t" \
    --expression-attribute-values '{":s": {"S": "RUNNING"}, ":r": {"S": "'"s3://${S3_BUCKET}/${SUBMISSION_ID}"'"}, ":t": {"S": "'"${START_TIME}"'"}}'
}

merge_statistics() {
  python3.7 ${LEADERBOARD_ROOT}/scripts/merge_statistics.py \
    --file-paths /logs/agent/agent{1..4}/agent_results.json \
    --endpoint $AGENT_RESULTS_FILE
}

generate_evalai_files() {
  python3.7 /workspace/evalai/generate_stdout.py \
    --file-path $AGENT_RESULTS_FILE \
    --endpoint $EVALAI_STDOUT_FILE
  python3.7 /workspace/evalai/generate_results.py  \
    --file-path $AGENT_RESULTS_FILE \
    --endpoint $EVALAI_RESULTS_FILE
  python3.7 /workspace/evalai/generate_metadata.py \
    --file-path $AGENT_RESULTS_FILE \
    --endpoint $EVALAI_METADATA_FILE
}

push_to_s3() {
  aws s3 sync /logs s3://${S3_BUCKET}/${SUBMISSION_ID}
}

get_submission_status() {
  ADDR="$EVALAI_API_SERVER/api/jobs/submission/$SUBMISSION_ID"
  HEADER="Authorization: Bearer $EVALAI_AUTH_TOKEN"
  STATUS=$(curl --location --request GET "$ADDR" --header "${HEADER}" | jq ".status" | sed 's:^.\(.*\).$:\1:')
  echo $STATUS
}

update_partial_submission_status() {
  STDOUT_STR=$(jq -n -c --arg m "$(cat $EVALAI_STDOUT_FILE)" '$m')
  RESULTS_STR=$(jq -n -c --arg m "$(cat $EVALAI_RESULTS_FILE)" '$m')
  METADATA_STR=$(jq -n -c --arg m "$(cat $EVALAI_METADATA_FILE)" '$m')

  ADDR="$EVALAI_API_SERVER/api/jobs/challenges/$CHALLENGE_ID/update_partially_evaluated_submission/"
  HEADER="Authorization: Bearer $EVALAI_AUTH_TOKEN"
  DATA='{"submission": '"$SUBMISSION_ID"',
        "submission_status": "PARTIALLY_EVALUATED",
        "challenge_phase": '"$TRACK_ID"',
        "stdout": '"$STDOUT_STR"',
        "result": '"$RESULTS_STR"',
        "stderr": "",
        "metadata": '"$METADATA_STR"'}'
  curl --location --request PUT "$ADDR" --header "$HEADER" --header 'Content-Type: application/json' --data-raw "$DATA"
}

########################
## LOGCOPY PARAMETERS ##
########################
[[ -z "${LOGS_PERIOD}" ]] && export LOGS_PERIOD="10"
[ -f $SIMULATION_CANCEL_FILE ] && rm $SIMULATION_CANCEL_FILE

# Save all the outpus into a file, which will be sent to s3
exec > >(tee "$LOGCOPY_LOGS") 2>&1

update_database

while sleep ${LOGS_PERIOD} ; do
  echo ""
  echo "[$(date +"%Y-%m-%d %T")] Starting log copy"
  echo "> Merging statistics"
  merge_statistics

  echo "> Generating EvalAI files"
  generate_evalai_files

  echo "> Pushing to S3"
  push_to_s3

  echo "> Checking if the submission has been cancelled"
  if [[ $(get_submission_status) == "cancelled" ]] ; then
    echo "Detected that the submission has been cancelled. Stopping..."
    touch $SIMULATION_CANCEL_FILE
    push_to_s3
    break
  fi

  echo "> Updating partial submission status"
  update_partial_submission_status

  echo "> Checking end condition"
  DONE_FILES=$(find /logs/containers-status -name *.done* | wc -l)
  if [ $DONE_FILES -ge 8 ]; then
    echo "Detected that all containers have finished. Stopping..."
    touch $LOGCOPY_DONE_FILE
    merge_statistics
    generate_evalai_files
    push_to_s3
    break
  else
    echo "Detected that only $DONE_FILES out of the 8 containers have finished. Waiting..."
  fi

done
