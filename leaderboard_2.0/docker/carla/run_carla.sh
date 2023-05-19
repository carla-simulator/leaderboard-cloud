#!/bin/bash

echo "Starting CARLA server"
./CarlaUE4.sh -vulkan -carla-rpc-port=${CARLA_PORT} -RenderOffScreen -nosound -ini:[/Script/Engine.RendererSettings]:r.GraphicsAdapter=${NVIDIA_VISIBLE_DEVICES}
echo "Stopped CARLA server"
sleep 86400
exit 0
