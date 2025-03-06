#!/bin/bash

DOC_STRING="Build aws_uploader docker image."

USAGE_STRING=$(cat <<- END
Usage: $0 [-h|--help] [-t|--target-name TARGET]

The default target name is "uploader-20"
END
)

usage() { echo "${DOC_STRING}"; echo "${USAGE_STRING}"; exit 1; }

# Defaults
TARGET_NAME="uploader-20"

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

# Build docker image
echo "Building uploader docker"
docker build --force-rm \
    -t ${TARGET_NAME} \
    -f ${SCRIPT_DIR}/Dockerfile ${SCRIPT_DIR}
