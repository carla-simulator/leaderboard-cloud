#!/bin/bash

#######################
## DEFAULT VARIABLES ##
#######################
export SCENARIO_RUNNER_ROOT="/utils/scenario_runner"
export LEADERBOARD_ROOT="/utils/leaderboard"
export PYTHONPATH="${SCENARIO_RUNNER_ROOT}":"${LEADERBOARD_ROOT}":${PYTHONPATH}

LOGCOPY_DONE_FILE="/logs/containers-status/logcopy.done"
SIMULATION_CANCEL_FILE="/logs/containers-status/simulation.cancel"

###########
## UTILS ##
###########
get_submission_status() {
  ADDR="$EVALAI_API_SERVER/api/jobs/submission/$SUBMISSION_PK"
  HEADER="Authorization: Bearer $AUTH_TOKEN"
  STATUS=$(curl --location --request GET "$ADDR" --header "${HEADER}" | jq ".status" | sed 's:^.\(.*\).$:\1:')
  echo $STATUS
}

update_partial_submission_status() {
  # TODO partially evaluates, void results and read stdout
  # Update partial submission status
  ADDR="$EVALAI_API_SERVER/api/jobs/challenge/$CHALLENGE_ID/update_submission/"
  HEADER="Authorization: Bearer $AUTH_TOKEN"
  DATA='{"submission": '"${SUBMISSION_ID}"', "submission_status": "RUNNING"}'
  curl --location --request PATCH "$ADDR" --header "$HEADER" --header 'Content-Type: application/json' --data-raw "$DATA"

  aws dynamodb update-item \
    --table-name beta-leaderboard-20 \
    --region "us-west-2" \
    --key '{"team_id": {"S": "${TEAM_ID}" }, "submission_id": {"S": "${SUBMISSION_ID}"} }' \
    --update-expression "SET submission_status = :s, results = :r" \
    --expression-attribute-values '{":s": {"S": "Running"}, ":r": {"S", '"s3://${S3_BUCKET}/${SUBMISSION_ID}"'}}'
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
    aws s3 sync /logs s3://${S3_BUCKET}/${SUBMISSION_ID}
    break
  fi

done
