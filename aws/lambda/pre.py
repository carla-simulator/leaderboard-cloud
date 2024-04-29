import base64
import datetime
import json
import time
import urllib3

import boto3
import botocore.exceptions

EVALAI_SECRET_NAME = "staging-evalai"  # "evalai"
EVALAI_TRACKS_SECRET_NAME = "staging-evalai-tracks"  # "evalai-tracks"

pool_manager = urllib3.PoolManager()

# aws resources
secretsmanager = boto3.client("secretsmanager")
dynamodb = boto3.resource("dynamodb")


def get_secret(secret_id):
    try:
        response = secretsmanager.get_secret_value(SecretId=secret_id)
    except botocore.exceptions.ClientError as e:
        raise e
    else:
        if "SecretString" in response:
            secret = response["SecretString"]
        else:
            secret = base64.b64decode(response["SecretBinary"])

        secret = json.loads(secret)

        # detect string list (string separated by commas)
        for k, v in secret.items():
            if "," in v:
                secret[k] = {str(item.split(":")[0]).strip():str(item.split(":")[1]).strip() for item in v.split(",") if item}

        return secret


def _is_submission_eligible(submission_data):
    return submission_data["submission"]["submission_status"] in ("SUBMITTED", "RESUMING")


def _is_team_allowed(submission_data):
    if not submission_data["qualifier"]["threshold_map"]:
        # always allow if not qualifier threshold map is specified (i.e, qualifying disabled)
        return True

    if bool(submission_data["qualifier"]["is_qualifying"]):
        # always allow to apply to qualifier tracks
        return True

    qualifier_table = dynamodb.Table(submission_data["aws"]["dynamodb_qualifier_table"])
    return "Item" in qualifier_table.get_item(Key={
        "team_id": submission_data["submission"]["team_id"],
        "track_codename": submission_data["submission"]["track_codename"]
    })


def _get_parallelization_workers(submission_id, team_id, user_desired_workers, dynamodb_submissions_table):
    qualifier_table = dynamodb.Table(dynamodb_submissions_table)
    response = qualifier_table.get_item(Key={
        "team_id": team_id,
        "submission_id": submission_id
    })

    db_workers = str(response["Item"].get("parallelization_workers", "")) if "Item" in response else ""

    if db_workers:
        return db_workers
    return user_desired_workers


def lambda_handler(event, context):

    evalai_secrets = get_secret(secret_id=EVALAI_SECRET_NAME)

    submission_data = {}
    try:
        submission_data = json.loads(pool_manager.request(
            method="GET",
            url="{0}{1}{2}".format(evalai_secrets["api_server"], "/api/jobs/submission/", str(event["submission_pk"])),
            headers={"Authorization": "Bearer {}".format(evalai_secrets["auth_token"])},
        ).data)
    except:
        pass

    track_secrets = get_secret(secret_id=EVALAI_TRACKS_SECRET_NAME)
    cluster_id, track_codename = track_secrets[str(event["phase_pk"])].split(":", 1)
    cluster_secrets = get_secret(secret_id=cluster_id)

    data = {
        "cluster": {
            "id": cluster_id,
            "name": cluster_secrets["name"],
            "endpoint": cluster_secrets["endpoint"],
            "certificate_authority": cluster_secrets["certificate_authority"],
            "instance_type": cluster_secrets["instance_type"][track_codename],
            "parallelization_workers": _get_parallelization_workers(str(event["submission_pk"]),str(submission_data.get("participant_team", "")), cluster_secrets["parallelization_workers"][track_codename], cluster_secrets["dynamodb_submissions_table"]),
            "simulator_image": cluster_secrets["simulator_image"],
            "leaderboard_image": cluster_secrets["leaderboard_image"],
            "uploader_image": cluster_secrets["uploader_image"],
            "monitor_image": cluster_secrets["monitor_image"]
        },
        "submission": {
            "submission_id": str(event["submission_pk"]),
            "challenge_id": str(event["challenge_pk"]),
            "team_id": str(submission_data.get("participant_team", "")),
            "team_name": str(submission_data.get("participant_team_name", "")),
            "submission_status": str(submission_data.get("status", "FAILED")).upper(),
            "track_id": str(event["phase_pk"]),
            "track_codename": track_codename.upper(),
            "resume": "1" if str(submission_data.get("status", "")).upper() == "RESUMING" else "",
            "routes": cluster_secrets["routes"][track_codename],
            "submitted_image_uri": str(event["submitted_image_uri"]),
        },
        "qualifier": {
            "is_qualifying": "1" if cluster_secrets["qualifier_map"] and track_codename in cluster_secrets["qualifier_map"] else "",
            "qualifying_to": cluster_secrets["qualifier_map"].get(track_codename, "").upper() if cluster_secrets["qualifier_map"] else "",
            "threshold_map": cluster_secrets["qualifier_threshold_map"]
        },
        "aws": {
            "s3_bucket": cluster_secrets["s3_bucket"],
            "dynamodb_submissions_table": cluster_secrets["dynamodb_submissions_table"],
            "dynamodb_qualifier_table": cluster_secrets["dynamodb_qualifier_table"]
        },
        "evalai": {
            "auth_token": evalai_secrets["auth_token"],
            "api_server": evalai_secrets["api_server"]
        },
        "results": {},
    }

    # add submission to database
    submissions_table = dynamodb.Table(data["aws"]["dynamodb_submissions_table"])
    submissions_table.put_item(Item={
        "submission_id": data["submission"]["submission_id"],
        "team_id": data["submission"]["team_id"],
        "team_name": data["submission"]["team_name"],
        "submission_status": data["submission"]["submission_status"],
        "track_id": data["submission"]["track_id"],
        "track_name": data["submission"]["track_codename"],
        "submitted_image_uri": data["submission"]["submitted_image_uri"],
        "parallelization_workers": data["cluster"]["parallelization_workers"],
        "submitted_time": f"{datetime.datetime.now().strftime('%Y-%m-%d %T%Z')} {time.tzname[time.daylight]}",
        "start_time": "-",
        "end_time": "-"
    })

    return {
        "is_eligible": _is_submission_eligible(data),
        "is_allowed": _is_team_allowed(data),
        "data": data
    }
