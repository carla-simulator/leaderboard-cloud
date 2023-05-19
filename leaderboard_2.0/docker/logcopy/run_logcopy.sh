#!/bin/bash

#######################
## DEFAULT VARIABLES ##
#######################
export SCENARIO_RUNNER_ROOT="/utils/scenario_runner"
export LEADERBOARD_ROOT="/utils/leaderboard"
export PYTHONPATH="${SCENARIO_RUNNER_ROOT}":"${LEADERBOARD_ROOT}":${PYTHONPATH}

########################
## LOGCOPY PARAMETERS ##
########################
[[ -z "${LOGS_PERIOD}" ]] && export LOGS_PERIOD="10"

while sleep ${LOGS_PERIOD} ; do
  echo "> Merging statistics"
  python3.7 ${LEADERBOARD_ROOT}/scripts/merge_statistics.py \
    --file-paths /logs/agent{1..4}/agent_results.json \
    --endpoint /logs/agent_results.json

  echo "> Pushing to S3"
  aws s3 sync /logs s3://beta-leaderboard-20/0

  echo "> Pusing to evalai" # TODO

done

exit 0
