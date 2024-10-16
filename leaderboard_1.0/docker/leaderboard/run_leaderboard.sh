#!/bin/bash

# Get the file names of this attempt
ID="$WORKER_ID"
CRASH_ID=$(find /tmp/status -name *agent-$ID.crash* | wc -l)
AGENT_LOGS="/tmp/logs/agent-$ID.log"
AGENT_CRASH_FILE="/tmp/status/agent-$ID.crash$CRASH_ID"
AGENT_DONE_FILE="/tmp/status/agent-$ID.done"
SIMULATOR_CRASH_FILE="/tmp/status/simulator-$ID.crash$CRASH_ID"
SIMULATOR_DONE_FILE="/tmp/status/simulator-$ID.done"
SIMULATION_CANCEL_FILE="/tmp/status/simulation-$ID.cancel"

AGENT_RESULTS="/tmp/agent/partial_agent_results$ID.json"

MAX_IDLE=800

#######################
## DEFAULT VARIABLES ##
#######################
export CARLA_ROOT="/workspace/CARLA"
export SCENARIO_RUNNER_ROOT="/workspace/scenario_runner"
export LEADERBOARD_ROOT="/workspace/leaderboard"
export PYTHONPATH="${CARLA_ROOT}/PythonAPI/carla/dist/$(ls ${CARLA_ROOT}/PythonAPI/carla/dist | grep py3.):${SCENARIO_RUNNER_ROOT}":"${LEADERBOARD_ROOT}":${PYTHONPATH}

############################
## LEADERBOARD PARAMETERS ##
############################
[[ -z "${CHALLENGE_TRACK_CODENAME}" ]]  && export CHALLENGE_TRACK_CODENAME="SENSORS"
[[ -z "${ROUTES}" ]]                    && export ROUTES="/workspace/leaderboard/data/routes_testing.xml"
[[ -z "${SCENARIOS}" ]]                 && export SCENARIOS="/workspace/leaderboard/data/all_towns_traffic_scenarios_private.json"
[[ -z "${REPETITIONS}" ]]               && export REPETITIONS="5"
[[ -z "${RESUME}" ]]                    && export RESUME=""

export CHECKPOINT_ENDPOINT="$AGENT_RESULTS"
export RECORD_PATH="/home/carla/recorder"
export DEBUG_CHALLENGE="0"

############################
## LEADERBOARD EXECUTION  ##
############################

# Save all the outpus into a file, which will be sent to s3
exec > >(tee -a "$AGENT_LOGS") 2>&1

if [ -f "$AGENT_LOGS" ]; then
    echo ""
    echo "Found partial agent logs"
fi

echo ""
UUID=$(cat /gpu/gpu.txt)
echo "Using GPU: ${UUID} (${NVIDIA_VISIBLE_DEVICES})"
echo ""

# Check for any previous trial. If so resume
if [ $CRASH_ID -gt 0 ]; then
    PREVIOUS_AGENT_CRASH_FILE="/tmp/status/agent-$ID.crash$(($CRASH_ID - 1))"
    if [ -f $PREVIOUS_AGENT_CRASH_FILE ]; then
        echo "Found the agent failure file. Resuming..."
        export RESUME="1"
    fi
else
    echo "Found no agent failure file"
fi

if [ -f "$AGENT_RESULTS" ]; then
    echo "Found partial agent results file. Resuming..."
    export RESUME="1"
    cat $AGENT_RESULTS
    echo ""
fi

# Get the modification date of a file
file_age () {
    echo "$(($(date +%s) - $(stat -c %Y "$1" )))"
}

# Stop all processes
kill_all_processes() {
    # Avoid exiting the script if pkill fails. We are not setting exit on error
    # (i.e., set -e) but users may enable it during agent_sources.sh
    pkill -9 'python|java|ros|publisher|catkin' || true
}

# Ending function before exitting the container
kill_and_wait_for_simulator () {
    kill_all_processes

    if [ "$1" = "crash" ]; then
        echo "Creating the agent crash file"
        touch $AGENT_CRASH_FILE
    else 
        echo "Creating the agent done file"
        touch $AGENT_DONE_FILE
    fi

    echo "Waiting for the simulator to finish..."
    for ((i=1;i<=60;i++)); do
        [ -f $SIMULATOR_CRASH_FILE ] && break
        [ -f $SIMULATOR_DONE_FILE ] && break
        sleep 10
    done 

    if [ "$1" = "crash" ]; then
        echo "Detected that the simulator has finished. Exiting with crash..."
    else 
        echo "Detected that the simulator has finished. Exiting with success..."
    fi
}

echo "Sourcing '${HOME}/agent_sources.sh'"
source ${HOME}/.bashrc
if [[ -f "${HOME}/agent_sources.sh" ]]; then
  source ${HOME}/agent_sources.sh
fi

echo ""
echo "Sleeping a bit to ensure CARLA is ready"
sleep 60
echo "Starting the Leaderboard"

# To ensure the Leaderboard never blocks, run it in the background (Done using the '&' at the end)
# while monitoring the changes to the results to know when it has finished.
python3 -u ${LEADERBOARD_ROOT}/leaderboard/leaderboard_evaluator.py \
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
    --debug=${DEBUG_CHALLENGE} &

while sleep 5 ; do
    if [ "$(file_age $AGENT_LOGS)" -gt "$MAX_IDLE" ]; then
        echo ""
        echo "Detected no new outputs for $AGENT_LOGS during $MAX_IDLE seconds. Stopping..."
        break
    fi
    if ! pgrep -f leaderboard_evaluator | egrep -q -v '^1$'; then
        echo ""
        echo "Detected that the leaderboard has finished"
        break
    fi
    if [ -f $SIMULATOR_CRASH_FILE ]; then
        echo ""
        echo "Detected that the simulator has crashed. Stopping..."
        break
    fi
    if [ -f $SIMULATION_CANCEL_FILE ]; then
        echo ""
        echo "Detected that the submission has been cancelled. Stopping..."
        kill_all_processes
        exit 0
    fi
done

sleep 5

echo ""
echo "Validating the Leaderboard results..."
if ! [ -f $AGENT_RESULTS ] || grep -wq "global_record\": {}" $AGENT_RESULTS; then
    echo "Detected missing global records"
    kill_and_wait_for_simulator crash
    exit 1
else
    echo "Detected correct global records"
    kill_and_wait_for_simulator
    exit 0
fi

# To test the resume functionality, you can use this random number generation
# if [ $[ $RANDOM % 100] -gt 50 ]; then
