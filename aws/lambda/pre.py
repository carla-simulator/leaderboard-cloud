import base64
import datetime
import json
import time
import urllib3

import boto3
import botocore.exceptions

EVALAI_SECRET_NAME = "staging-evalai"  # "evalai"
EVALAI_TRACKS_SECRET_NAME = "staging-evalai-tracks"  # "evalai-tracks"

manager = urllib3.PoolManager()

session = boto3.session.Session()
client = session.client(
    service_name="secretsmanager",
)


def get_secret(secret_id):
    try:
        response = client.get_secret_value(SecretId=secret_id)
    except botocore.exceptions.ClientError as e:
        raise e
    else:
        if "SecretString" in response:
            secret = response["SecretString"]
        else:
            secret = base64.b64decode(response["SecretBinary"])
        return json.loads(secret)


def lambda_handler(event, context):

    evalai_secrets = get_secret(secret_id=EVALAI_SECRET_NAME)

    submission_data = {}
    try:
        submission_data = json.loads(manager.request(
            method="GET",
            url="{0}{1}{2}".format(evalai_secrets["api_server"], "/api/jobs/submission/", str(event["submission_pk"])),
            headers={"Authorization": "Bearer {}".format(evalai_secrets["auth_token"])},
        ).data)
    except:
        pass

    # TODO: add to cluster secrets parallelization parameters
    track_secrets = get_secret(secret_id=EVALAI_TRACKS_SECRET_NAME)
    cluster_id, track_codename = track_secrets[str(event["phase_pk"])].rsplit("-", 1)
    cluster_secrets = get_secret(secret_id=cluster_id)
 
    out_ = {
        "cluster": {
            "id": cluster_id,
            "name": cluster_secrets["name"],
            "endpoint": cluster_secrets["endpoint"],
            "certificate_authority": cluster_secrets["certificate_authority"],
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
            "submitted_image_uri": str(event["submitted_image_uri"])
        },
        "parallelization": {
            "gpus": cluster_secrets.get("parallelization_gpus", "1"),
            "workers": cluster_secrets.get("parallelization_workers", "4")
        },
        "aws": {
            "s3_bucket": cluster_secrets["s3_bucket"],
            "dynamodb_submissions_table": cluster_secrets["dynamodb_submissions_table"],
        },
        "evalai": {
            "auth_token": evalai_secrets["auth_token"],
            "api_server": evalai_secrets["api_server"]
        },
        "results": {},
        "is_eligible": True
    }

    # add submission to database
    # TODO: Add submission parallelization parameters?
    # What happens if the submission is resuming
    dynamodb = boto3.resource('dynamodb')
    submissions_table = dynamodb.Table(out_["aws"]["dynamodb_submissions_table"])
    submissions_table.put_item(Item={
        "submission_id": out_["submission"]["submission_id"],
        "team_id": out_["submission"]["team_id"],
        "team_name": out_["submission"]["team_name"],
        "submission_status": out_["submission"]["submission_status"],
        "track_id": out_["submission"]["track_id"],
        "track_name": out_["submission"]["track_codename"],
        "submitted_image_uri": out_["submission"]["submitted_image_uri"],
        "submitted_time": f"{datetime.datetime.now().strftime('%Y-%m-%d %T%Z')} {time.tzname[time.daylight]}",
        "start_time": "-",
        "end_time": "-"
    })

    return out_