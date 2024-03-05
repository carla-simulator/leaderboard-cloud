
#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

uuid=$(cat ${SCRIPT_DIR}/gpu.txt)

readarray -t ALL_GPUS < <(nvidia-smi --query-gpu=index,uuid --format=csv | grep GPU)
for gpu in "${ALL_GPUS[@]}"; do  if [[ "$gpu" == *"$uuid"* ]]; then DEVICE=$(cut -d , -f 1 <<< $gpu) && break ; fi; done

echo $DEVICE
