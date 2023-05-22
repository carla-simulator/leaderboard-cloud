#!/bin/bash

echo "Starting CARLA server"
./CarlaUE4.sh  -carla-rpc-port=${CARLA_PORT} -opengl -nosound
echo "Stopped CARLA server"
exit 0