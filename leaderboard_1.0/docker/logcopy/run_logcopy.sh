#!/bin/bash

#######################
## DEFAULT VARIABLES ##
#######################
export SCENARIO_RUNNER_ROOT="/utils/scenario_runner"
export LEADERBOARD_ROOT="/utils/leaderboard"
export PYTHONPATH="${SCENARIO_RUNNER_ROOT}":"${LEADERBOARD_ROOT}":${PYTHONPATH}

LOGCOPY_DONE_FILE="/logs/containers-status/logcopy.done"

########################
## LOGCOPY PARAMETERS ##
########################
[[ -z "${LOGS_PERIOD}" ]] && export LOGS_PERIOD="10"

while sleep ${LOGS_PERIOD} ; do
  echo ""
  echo "[$(date +"%Y-%m-%d %T")] Starting log copy"
  echo "Merging statistics"
  python3.7 ${LEADERBOARD_ROOT}/scripts/merge_statistics.py \
    --file-paths /logs/agent{1..4}/agent_results.json \
    --endpoint /logs/agent_results.json

  echo "Pushing to S3"
  aws s3 sync /logs s3://beta-leaderboard-10/${SUBMISSION_ID}

  echo "Pushing to evalai" # TODO

  DONE_FILES=$(find /logs/containers-status -name *.done* | wc -l)
  echo "Number of finished containers: $DONE_FILES"
  if [ $DONE_FILES -ge 8 ]; then
    echo "Detected that all containers have finished. Stopping..."
    touch $LOGCOPY_DONE_FILE
    aws s3 sync /logs s3://beta-leaderboard-10/${SUBMISSION_ID}
    break
  fi

done
