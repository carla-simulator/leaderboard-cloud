#!/bin/bash

# Get the file names of this attempt
ID=$(($NVIDIA_VISIBLE_DEVICES + 1))
CRASH_ID=$(find /tmp/status -name *simulator-$ID.crash* | wc -l)
AGENT_CRASH_FILE="/tmp/status/agent-$ID.crash$CRASH_ID"
AGENT_DONE_FILE="/tmp/status/agent-$ID.done"
SIMULATOR_CRASH_FILE="/tmp/status/simulator-$ID.crash$CRASH_ID"
SIMULATOR_DONE_FILE="/tmp/status/simulator-$ID.done"
SIMULATION_CANCEL_FILE="/tmp/status/simulation.cancel"

# Ending function before exitting the container
kill_all_processes() {
    pkill -9 'CarlaUE4'
}

kill_and_wait_for_agent () {
    kill_all_processes

    if [ "$1" = "crash" ]; then
        echo "Creating the simulator crash file"
        touch $SIMULATOR_CRASH_FILE
    else 
        echo "Creating the simulator done file"
        touch $SIMULATOR_DONE_FILE
    fi

    echo "Waiting for the agent to finish..."
    for ((i=1;i<=60;i++)); do
        [ -f $AGENT_CRASH_FILE ] && break
        [ -f $AGENT_DONE_FILE ] && break
        sleep 10
    done

    if [ "$1" = "crash" ]; then
        echo "Detected that the agent has finished. Exiting with crash..."
    else 
        echo "Detected that the agent has finished. Exiting with success..."
    fi
}

echo ""
echo "Starting CARLA server"
./CarlaUE4.sh -vulkan -carla-rpc-port=${CARLA_PORT} -RenderOffScreen -nosound -ini:[/Script/Engine.RendererSettings]:r.GraphicsAdapter=${NVIDIA_VISIBLE_DEVICES} &


while sleep 5 ; do
    if [ -f $AGENT_CRASH_FILE ]; then
        echo ""
        echo "Detected that the Leaderboard has failed. Stopping the server..."
        kill_and_wait_for_agent crash
        exit 1
    fi
    if [ -f $AGENT_DONE_FILE ]; then
        echo ""
        echo "Detected that the Leaderboard has finished. Stopping the server..."
        kill_and_wait_for_agent
        exit 0
    fi
    if [ -z "$(pgrep -f CarlaUE4)" ]; then
        echo ""
        echo "Detected that the server has crashed"
        kill_and_wait_for_agent crash
        exit 1
    fi
    if [ -f $SIMULATION_CANCEL_FILE ]; then
        echo ""
        echo "Detected that the submission has been cancelled. Stopping..."
        kill_all_processes
        exit 0
    fi
done
