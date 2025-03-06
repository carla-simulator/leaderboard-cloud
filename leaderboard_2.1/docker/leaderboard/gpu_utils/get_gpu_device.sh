
#!/bin/bash

GPU_DEVICE_FILE=${1}

uuid=$(cat ${GPU_DEVICE_FILE})

readarray -t ALL_GPUS < <(nvidia-smi --query-gpu=index,uuid --format=csv | grep GPU)
for gpu in "${ALL_GPUS[@]}"; do  if [[ "$gpu" == *"$uuid"* ]]; then DEVICE=$(cut -d , -f 1 <<< $gpu) && break ; fi; done

echo $DEVICE
