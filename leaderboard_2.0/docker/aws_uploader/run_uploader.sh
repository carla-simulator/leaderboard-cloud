#!/bin/bash

#######################
## DEFAULT VARIABLES ##
#######################
ID="$WORKER_ID"

UPLOADER_LOGS="/logs/uploader/uploader-$ID.log"
UPLOADER_DONE_FILE="/logs/containers-status/uploader-$ID.done"

SIMULATION_CANCEL_FILE="/logs/containers-status/simulation-$ID.cancel"

###########
## UTILS ##
###########
push_to_s3() {
  aws s3 sync /logs s3://${S3_BUCKET}/${SUBMISSION_ID} --no-progress
}

#########################
## UPLOADER PARAMETERS ##
#########################
[[ -z "${UPLOADER_PERIOD}" ]] && export UPLOADER_PERIOD="30"
[ -f $SIMULATION_CANCEL_FILE ] && rm $SIMULATION_CANCEL_FILE

# Save all the outpus into a file, which will be sent to s3
exec > >(tee "$UPLOADER_LOGS") 2>&1

while sleep ${UPLOADER_PERIOD} ; do
  echo ""
  echo "[$(date +"%Y-%m-%d %T")] Starting loop uploader"

  echo "> Pushing to S3"
  push_to_s3

  echo "> Checking if the submission has been cancelled"
  aws s3api head-object --bucket ${S3_BUCKET} --key ${SUBMISSION_ID}/monitor/simulation.cancel > /dev/null 2>&1 && SIMULATION_CANCELLED=true
  if [ $SIMULATION_CANCELLED ]; then
    echo "Detected that the submission has been cancelled. Stopping..."
    touch $SIMULATION_CANCEL_FILE
    push_to_s3
    break
  fi

  echo "> Checking end condition"
  DONE_FILES=$(find /logs/containers-status -name *.done* | wc -l)
  if [ $DONE_FILES -ge 2 ]; then
    echo "Detected that all containers have finished. Stopping..."
    touch $UPLOADER_DONE_FILE
    push_to_s3
    break
  else
    echo "Detected that only $DONE_FILES out of the 2 containers have finished. Waiting..."
  fi

done
