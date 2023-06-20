import base64
import json
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
    phase_data = json.loads(manager.request(
        method="GET",
        url="{0}{1}{2}".format(evalai_secrets["api_server"], "/api/challenges/challenge/phase/", event["phase_pk"]),
        headers={"Authorization": "Bearer {}".format(evalai_secrets["auth_token"])},
    ).data)

    if phase_data.get("codename", "").startswith("leaderboard-10"):
        cluster_secrets = get_secret(secret_id="leaderboard-10")
    else:
        cluster_secrets = get_secret(secret_id="leaderboard-20")

    return {
        "cluster": {
            "id": 1 if phase_data.get("codename", "").startswith("leaderboard-10") else 2,
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
            "track_codename": phase_data.get("codename", "").rsplit("-", 1)[1],
            "resume": "1" if str(submission_data.get("status", "")).upper() == "RESUMING" else "",
            "submitted_image_uri": str(event["submitted_image_uri"])
        },
        "aws": {
            "s3_bucket": cluster_secrets["s3_bucket"],
            "dynamodb_table": cluster_secrets["dynamodb_table"]
        },
        "evalai": {
            "auth_token": evalai_secrets["auth_token"],
            "api_server": evalai_secrets["api_server"]
        }
    }
