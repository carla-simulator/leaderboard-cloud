#!/bin/bash

DOC_STRING="Build CARLA docker image."

USAGE_STRING=$(cat <<- END
Usage: $0 [-h|--help] [-t|--target-name TARGET]

The default target name is "carla-10"

The following env variables are mandatory:
  * CARLA_ROOT
END
)

usage() { echo "${DOC_STRING}"; echo "${USAGE_STRING}"; exit 1; }

# Defaults
TARGET_NAME="carla-10"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -t | --target-name )
      TARGET_NAME=$2
      shift 2 ;;
    -h | --help )
      usage
      ;;
    * )
      shift ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -z "$CARLA_ROOT" ]
then
    echo "Error $CARLA_ROOT is empty. Set \$CARLA_ROOT as an environment variable first."
    exit 1
fi

# Temporary copying run_carla script in ${CARLA_ROOT}
cp ${SCRIPT_DIR}/run_carla.sh ${CARLA_ROOT}

# Build docker image
echo "Building CARLA docker"
echo "Using CARLA version: ${CARLA_ROOT}"
docker build --force-rm \
    -t ${TARGET_NAME} \
    -f ${SCRIPT_DIR}/Dockerfile ${CARLA_ROOT}

rm -fr ${CARLA_ROOT}/run_carla.sh