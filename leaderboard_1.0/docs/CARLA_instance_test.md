## Running CARLA on the instance

```bash
# 1) Install X server stuff (No idea what this does, and it doesn't seem to be needed for a local instance test)
sudo apt-get update
sudo apt-get install x11-xserver-utils
sudo apt-get install xdg-user-dirs
sudo apt-get install xdg-utils

grep --quiet tsc /sys/devices/system/clocksource/clocksource0/available_clocksource && sudo bash -c 'echo tsc > /sys/devices/system/clocksource/clocksource0/current_clocksource'
sudo nvidia-xconfig --preserve-busid -a --virtual=1280x1024
sudo X :0 -screen Screen0

# 2) Login to AWS
mkdir .aws
cat > .aws/credentials << EOF
[default]
aws_access_key_id = xxx
aws_secret_access_key = xxx
EOF
sudo $(aws ecr get-login --no-include-email --region us-east-1)

# 3) Download the dockers
sudo docker pull 342236305043.dkr.ecr.us-east-1.amazonaws.com/leaderboard-20-simulator
sudo docker pull 342236305043.dkr.ecr.us-east-1.amazonaws.com/leaderboard-20

# 4) Copy the LB and SR parts out of the dockers

sudo docker run -it --rm --volume=/tmp:/tmp:rw 342236305043.dkr.ecr.us-east-1.amazonaws.com/leaderboard-20 /bin/bash
sudo docker ps
export CONTAINER_ID=<container-id>
sudo docker cp $CONTAINER_ID:/workspace/scenario_runner/ /tmp/scenario-runner-master/
sudo docker cp $CONTAINER_ID:/workspace/leaderboard/ /tmp/leaderboard-master/
sudo docker cp $CONTAINER_ID:/workspace/CARLA/ /tmp/carla-root-master/

# 5) Run CARLA
export DISPLAY=0.1
sudo docker run -it --rm --net=host --runtime=nvidia \
 -e DISPLAY=$DISPLAY \
 -e XAUTHORITY=$XAUTHORITY \
 -v /tmp/.X11-unix:/tmp/.X11-unix \
 -v $XAUTHORITY:$XAUTHORITY \
 --gpus=all \
 342236305043.dkr.ecr.us-east-1.amazonaws.com/leaderboard-20-simulator ./CarlaUE4.sh --vulkan -RenderOffScreen

# 6) Download and run the agent (using a LB 2.0 submitted agent as the test)
export AGENT_IMAGE=342236305043.dkr.ecr.us-east-1.amazonaws.com/bm-586a194d-team-177:54a1db1b-d340-4de8-a25b-67aa756db0c6
sudo docker pull $AGENT_IMAGE

sudo docker run -it --rm --net=host --runtime=nvidia --gpus all \
    -e ROUTES=/workspace/leaderboard/data/routes_testing.xml \
    --volume=/tmp/scenario-runner-master/:/workspace/scenario_runner/:rw \
    --volume=/tmp/leaderboard-master/:/workspace/leaderboard/:rw \
    --volume=/tmp/carla-root-master/:/workspace/CARLA/:rw $AGENT_IMAGE leaderboard/scripts/run_evaluation.sh
```

