#!/bin/bash

#######################
## DEFAULT VARIABLES ##
#######################
export SCENARIO_RUNNER_ROOT="/utils/scenario_runner"
export LEADERBOARD_ROOT="/utils/leaderboard"
export PYTHONPATH="${SCENARIO_RUNNER_ROOT}":"${LEADERBOARD_ROOT}":${PYTHONPATH}

# TODO: REMOVE
export AUTH_TOKEN="eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ0b2tlbl90eXBlIjoicmVmcmVzaCIsImV4cCI6MTcwNzk4ODg5NiwianRpIjoiYzEzNTFiMTg0NmJiNDRkMjlhY2EwZmMyMDA2YzJjYjUiLCJ1c2VyX2lkIjo0MTd9.9i_tGvpfEpcIPFuwLRGpxrhPDmHB26p0HBJogQNw1ZA"
export EVALAI_API_SERVER="https://staging.eval.ai"

LOGCOPY_DONE_FILE="/logs/containers-status/logcopy.done"
SIMULATION_CANCEL_FILE="/logs/containers-status/simulation.cancel"
UPDATED_DB=false

###########
## UTILS ##
###########
get_submission_status() {
  ADDR="$EVALAI_API_SERVER/api/jobs/submission/$SUBMISSION_ID"
  HEADER="Authorization: Bearer $AUTH_TOKEN"
  STATUS=$(curl --location --request GET "$ADDR" --header "${HEADER}" | jq ".status" | sed 's:^.\(.*\).$:\1:')
  echo $STATUS
}

update_partial_submission_status() {
  STDOUT=$(cat /logs/evalai/stdout.txt)
  STDOUT_STR=$(jq -n -c --arg m "$STDOUT" '$m')

  RESULTS=$(cat /logs/evalai/results.json)
  RESULTS_STR=$(jq -n -c --arg m "$RESULTS" '$m')

  METADATA=$(cat /logs/evalai/metadata.json)
  METADATA_STR=$(jq -n -c --arg m "$METADATA" '$m')

  ADDR="$EVALAI_API_SERVER/api/jobs/challenges/$CHALLENGE_ID/update_partially_evaluated_submission/"
  HEADER="Authorization: Bearer $AUTH_TOKEN"
  DATA='{"submission": '"$SUBMISSION_ID"',
        "submission_status": "PARTIALLY_EVALUATED",
        "challenge_phase": '"$TRACK_ID"',
        "stdout": '"$STDOUT_STR"',
        "result": '"$RESULTS_STR"',
        "stderr": "",
        "metadata": '"$METADATA_STR"'}'
  curl --location --request PUT "$ADDR" --header "$HEADER" --header 'Content-Type: application/json' --data-raw "$DATA"

  if [ "$UPDATED_DB" = false ]; then
    aws dynamodb update-item \
      --table-name beta-leaderboard-20 \
      --region "us-west-2" \
      --key '{"team_id": {"S": '"${TEAM_ID}"' }, "submission_id": {"S": '"${SUBMISSION_ID}"'} }' \
      --update-expression "SET submission_status = :s, results = :r" \
      --expression-attribute-values '{":s": {"S": "Running"}, ":r": {"S", '"s3://${S3_BUCKET}/${SUBMISSION_ID}"'}}'
    UPDATED_DB=true
  fi
}

generate_evalai_files() {
  python3.7 ${LEADERBOARD_ROOT}/scripts/generate_evalai_stdout.py \
    --file-path /logs/agent_results.json \
    --endpoint /logs/evalai/stdout.txt
  python3.7 ${LEADERBOARD_ROOT}/scripts/generate_evalai_results.py \
    --file-path /logs/agent_results.json \
    --endpoint /logs/evalai/results.json
  cp /logs/agent_results.json /logs/evalai/metadata.json
}

########################
## LOGCOPY PARAMETERS ##
########################
[[ -z "${LOGS_PERIOD}" ]] && export LOGS_PERIOD="10"
[ -f $SIMULATION_CANCEL_FILE ] && rm $SIMULATION_CANCEL_FILE

while sleep ${LOGS_PERIOD} ; do
  echo ""
  echo "[$(date +"%Y-%m-%d %T")] Starting log copy"
  echo "Merging statistics"
  python3.7 ${LEADERBOARD_ROOT}/scripts/merge_statistics.py \
    --file-paths /logs/agent{1..4}/agent_results.json \
    --endpoint /logs/agent_results.json

  generate_evalai_files

  echo "Pushing to S3"
  aws s3 sync /logs s3://${S3_BUCKET}/${SUBMISSION_ID}

  echo "Checking if the submission has been cancelled"
  if [ $(get_submission_status) == "cancelled" ] ; then
    echo "Detected that the submission has been cancelled. Stopping..."
    touch $SIMULATION_CANCEL_FILE
    aws s3 sync /logs s3://${S3_BUCKET}/${SUBMISSION_ID}
    break
  fi

  echo "Updating partial submission status"
  update_partial_submission_status

  DONE_FILES=$(find /logs/containers-status -name *.done* | wc -l)
  echo "Number of finished containers: $DONE_FILES"
  if [ $DONE_FILES -ge 8 ]; then
    echo "Detected that all containers have finished. Stopping..."
    touch $LOGCOPY_DONE_FILE
    generate_evalai_files
    aws s3 sync /logs s3://${S3_BUCKET}/${SUBMISSION_ID}
    break
  fi

done
