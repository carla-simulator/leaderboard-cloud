#!/bin/bash
DOC_STRING="Download submission logs from S3 bucket."

USAGE_STRING=$(cat <<- END
Usage: $0 [-h|--help] [-b|--bucket] [-s|--submission-id] [--all]

By default, the S3 bucket is staging-leaderboard-20

END
)

usage() { echo "${DOC_STRING}"; echo "${USAGE_STRING}"; exit 1; }

# Defaults
BUCKET="staging-leaderboard-20"
SUBMISSION_ID="0"
ALL=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -s | --submission_id )
      SUBMISSION_ID=$2
      shift 2 ;;
    -b | --bucket )
      BUCKET=$2
      shift 2 ;;
    --all )
      ALL=true
      shift ;;
    -h | --help )
      usage
      ;;
    * )
      shift ;;
  esac
done


if [ $ALL = true ]; then
  aws s3 cp s3://$BUCKET/$SUBMISSION_ID $SUBMISSION_ID --recursive
else
  aws s3 cp s3://$BUCKET/$SUBMISSION_ID $SUBMISSION_ID --recursive --exclude "recorder/*"
fi
