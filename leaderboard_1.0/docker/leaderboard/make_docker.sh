#!/bin/bash

DOC_STRING="Build leaderboard docker image."

USAGE_STRING=$(cat <<- END
Usage: $0 [-h|--help] [-t|--target-name TARGET]

The default target name is "leaderboard-10"

The following env variables are mandatory:
  * CARLA_ROOT
  * LEADERBOARD_ROOT
  * SCENARIO_RUNNER_ROOT
  * CHALLENGE_CONTENTS_ROOT
END
)

usage() { echo "${DOC_STRING}"; echo "${USAGE_STRING}"; exit 1; }

# Defaults
TARGET_NAME="leaderboard-10"

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

if [ -z "$SCENARIO_RUNNER_ROOT" ]
then echo "Error $SCENARIO_RUNNER_ROOT is empty. Set \$SCENARIO_RUNNER_ROOT as an environment variable first."
    exit 1
fi

if [ -z "$LEADERBOARD_ROOT" ]
then echo "Error $LEADERBOARD_ROOT is empty. Set \$LEADERBOARD_ROOT as an environment variable first."
    exit 1
fi

if [ -z "$CHALLENGE_CONTENTS_ROOT" ]
then echo "Error $CHALLENGE_CONTENTS_ROOT is empty. Set \$CHALLENGE_CONTENTS_ROOT as an environment variable first."
    exit 1
fi

rm -fr .lbtmp
mkdir .lbtmp
mkdir -p .lbtmp/team_code

echo "Copying CARLA Python API"
cp -fr ${CARLA_ROOT}/PythonAPI  .lbtmp
mv .lbtmp/PythonAPI/carla/dist/carla*-py2*.egg .lbtmp/PythonAPI/carla/dist/carla-leaderboard-py2.7.egg
mv .lbtmp/PythonAPI/carla/dist/carla*-py3*.egg .lbtmp/PythonAPI/carla/dist/carla-leaderboard-py3x.egg

echo "Copying Scenario Runner"
cp -fr ${SCENARIO_RUNNER_ROOT}/ .lbtmp
rm -fr .lbtmp/scenario_runner/.git

echo "Copying Leaderboard"
cp -fr ${LEADERBOARD_ROOT}/ .lbtmp
rm -fr .lbtmp/leaderboard/.git

echo "Copying CARLA's private data"
cp ${CHALLENGE_CONTENTS_ROOT}/src/leaderboard/data/* .lbtmp/leaderboard/data
cp ${SCRIPT_DIR}/run_leaderboard.sh .lbtmp/leaderboard/

# build docker image
echo "Building docker"
docker build --force-rm --build-arg HTTP_PROXY=${HTTP_PROXY} \
             --build-arg HTTPS_PROXY=${HTTPS_PROXY} \
             --build-arg http_proxy=${http_proxy} \
             -t ${TARGET_NAME} -f ${SCRIPT_DIR}/Dockerfile .lbtmp

rm -fr .lbtmp
