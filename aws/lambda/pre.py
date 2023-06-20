import base64
import datetime
import json
import time
import urllib3

import boto3
import botocore.exceptions

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

    evalai_secrets = get_secret(secret_id="evalai")
    submission_data = json.loads(manager.request(
        method="GET",
        url="{0}{1}{2}".format(evalai_secrets["api_server"], "/api/jobs/submission/", event["submission_pk"]),
        headers={"Authorization": "Bearer {}".format(evalai_secrets["auth_token"])},
    ).data)

    track_secrets = get_secret(secret_id="evalai-tracks")
    cluster_id, track_codename = track_secrets[event["phase_pk"]].rsplit("-", 1)
    cluster_secrets = get_secret(secret_id=cluster_id)

    return {
        "cluster": {
            "id": cluster_id,
            "name": cluster_secrets["name"],
            "endpoint": cluster_secrets["endpoint"],
            "certificate_authority": cluster_secrets["certificate_authority"],
            "simulator_image": cluster_secrets["simulator_image"],
            "leaderboard_image": cluster_secrets["leaderboard_image"],
            "logcopy_image": cluster_secrets["logcopy_image"]
        },
        "submission": {
            "name": "submission-{}".format(str(event["submission_pk"])),
            "challenge_id": str(event["challenge_pk"]),
            "submission_id": str(event["submission_pk"]),
            "team_id": str(submission_data.get("participant_team", "")),
            "team_name": str(submission_data.get("participant_team_name", "")),
            "submission_status": str(submission_data.get("status", "")).upper(),
            "track_id": str(event["phase_pk"]),
            "track_codename": track_codename.upper(),
            "resume": "1" if str(submission_data.get("status", "")).upper() == "RESUMING" else "",
            "submitted_image_uri": str(event["submitted_image_uri"]),
            "submitted_time": 0,
            "start_time": f"{datetime.datetime.now().strftime('%Y-%m-%dT%T%Z')}{time.tzname[time.daylight]}",
            "end_time": "",
        },
        "aws": {
            "s3_bucket": cluster_secrets["s3_bucket"],
            "dynamodb_table": cluster_secrets["dynamodb_table"]
        },
        "evalai": {
            "auth_token": evalai_secrets["auth_token"],
            "api_server": evalai_secrets["api_server"]
        },
        "results": {}
    }
