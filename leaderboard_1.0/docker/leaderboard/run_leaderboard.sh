#!/bin/bash

LEADERBOARD_LOGS=/tmp/agent/leaderboard.log
AGENT_RESULTS=/tmp/agent/agent_results.json
MAX_IDLE=800

#######################
## DEFAULT VARIABLES ##
#######################
export CARLA_ROOT="/workspace/CARLA"
export SCENARIO_RUNNER_ROOT="/workspace/scenario_runner"
export LEADERBOARD_ROOT="/workspace/leaderboard"
export PYTHONPATH="${CARLA_ROOT}/PythonAPI/carla/:${SCENARIO_RUNNER_ROOT}":"${LEADERBOARD_ROOT}":${PYTHONPATH}

############################
## LEADERBOARD PARAMETERS ##
############################
[[ -z "${CARLA_PORT}" ]]           && export CARLA_PORT="2000"
export CARLA_TM_PORT=$(($CARLA_PORT + 10))


[[ -z "${CHALLENGE_TRACK_CODENAME}" ]] && export CHALLENGE_TRACK_CODENAME="SENSORS"

export ROUTES="/workspace/leaderboard/data/routes_testing.xml"
export SCENARIOS="/workspace/leaderboard/data/all_towns_traffic_scenarios_public.json"
export REPETITIONS="5"
export RESUME=""

export CHECKPOINT_ENDPOINT="$AGENT_RESULTS"
export RECORD_PATH="/home/carla/CarlaUE4/Saved"

export DEBUG_CHALLENGE="0"

file_age () {
    echo "$(($(date +%s) - $(stat -c %Y "$1" )))"
} # Get the modification date of a file
kill_cleanup () {
    pkill -9 'python|java|ros|publisher|catkin'
} # Kill all possible remaining processes

echo "Sleeping a bit to ensure CARLA is ready"
sleep 60
echo "Starting the agent"

# To ensure the Leaderboard never blocks, run it in the background while monitoring the changes to the results
python3 -u ${LEADERBOARD_ROOT}/leaderboard/leaderboard_evaluator.py \
    --port=${CARLA_PORT} \
    --trafficManagerPort=${CARLA_TM_PORT} \
    --agent=${TEAM_AGENT} \
    --agent-config=${TEAM_CONFIG} \
    --track=${CHALLENGE_TRACK_CODENAME} \
    --routes=${ROUTES} \
    --routes-subset=${ROUTES_SUBSET} \
    --scenarios=${SCENARIOS} \
    --repetitions=${REPETITIONS} \
    --resume=${RESUME} \
    --checkpoint=${CHECKPOINT_ENDPOINT} \
    --record=${RECORD_PATH} \
    --debug=${DEBUG_CHALLENGE} |& tee $LEADERBOARD_LOGS &

while sleep 1 ; do
    if [ "$(file_age $LEADERBOARD_LOGS)" -gt "$MAX_IDLE" ]; then
        echo "No new outputs generated for $LEADERBOARD_LOGS during $MAX_IDLE seconds. Exiting"
        break
    fi
    if ! pgrep -f leaderboard_evaluator | egrep -q -v '^1$' ; then
        echo "Detected that the leaderboard has finished. Exiting"
        break
    fi
done

sleep 5
kill_cleanup

echo "Finished agent"
exit 0
