#!/bin/bash

# Get the file names of this attempt
ID="$WORKER_ID"
CRASH_ID=$(find /tmp/status -name *simulator-$ID.crash* | wc -l)

SIMULATOR_LOGS="/tmp/logs/simulator-$ID.log"
SIMULATOR_START_FILE="/tmp/status/simulator-$ID.start$CRASH_ID"
SIMULATOR_DONE_FILE="/tmp/status/simulator-$ID.done"
SIMULATOR_CRASH_FILE="/tmp/status/simulator-$ID.crash$CRASH_ID"

AGENT_DONE_FILE="/tmp/status/agent-$ID.done"
AGENT_CRASH_FILE="/tmp/status/agent-$ID.crash$CRASH_ID"

SIMULATION_CANCEL_FILE="/tmp/status/simulation-$ID.cancel"

GPU_DEVICE_FILE="/gpu/uuid.txt$CRASH_ID"

# Ending function before exitting the container
kill_all_processes() {
    # Avoid exiting on error
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

# Save all the outpus into a file, which will be sent to s3
exec > >(tee -a "$SIMULATOR_LOGS") 2>&1

if [ -f "$SIMULATOR_LOGS" ]; then
    echo ""
    echo "Found partial simulator logs"
fi

echo "Waiting for a GPU to be assigned..."
MAX_RETRIES=120  # wait 1h maximum
for ((i=1;i<=$MAX_RETRIES;i++)); do
    if [ -f $GPU_DEVICE_FILE ]; then
        echo ""
        echo "Detected that a GPU has been assigned"
        break
    fi
    sleep 30
done

if ! [ -f $GPU_DEVICE_FILE ]; then
    echo "No GPU assigned. Stopping..."
    kill_and_wait_for_agent crash
    exit 1
fi

echo ""
export NVIDIA_VISIBLE_DEVICES=$(/gpu/get_gpu_device.sh ${GPU_DEVICE_FILE})
UUID=$(cat ${GPU_DEVICE_FILE})
echo "Using GPU: ${UUID} (${NVIDIA_VISIBLE_DEVICES})"

echo "Starting CARLA server"
./CarlaUE4.sh -vulkan -RenderOffScreen -nosound -ini:[/Script/Engine.RendererSettings]:r.GraphicsAdapter=${NVIDIA_VISIBLE_DEVICES} &

echo "Sleeping a bit to ensure CARLA is ready"
sleep 60

touch $SIMULATOR_START_FILE

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
