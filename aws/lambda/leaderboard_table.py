import base64
import copy
import json
import urllib3

import boto3
import botocore.exceptions

session = boto3.session.Session()
client = session.client(
    service_name="secretsmanager",
)

RESULTS = [
    {
        'Driving score': 79.953,
        'Route completion': 89.895,
        'Infraction penalty': 0.886,
        'Collisions pedestrians': 0.018,
        'Collisions vehicles': 0.132,
        'Collisions layout': 0.008,
        'Red light infractions': 0.080,
        'Stop sign infractions': 0.000,
        'Off-road infractions': 0.042,
        'Route deviations': 0.000,
        'Route timeouts': 0.006,
        'Agent blocked': 0.325,
    }
]

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

    submission_status = "FINISHED"

    submission_data = copy.deepcopy(event)
    submission_data["submission"]["submission_status"] = submission_status
    submission_data["results"] = RESULTS

    evalai_secrets = get_secret(secret_id="evalai")
    manager = urllib3.PoolManager()
    try:
        evalai_status = ""

        out = json.loads(manager.request(
            method="PUT",
            url="{}{}{}{}".format(evalai_secrets["api_server"], "/api/jobs/challenge/", event["submission"]["challenge_id"], "/update_submission/"),
            headers={"Authorization": "Bearer {}".format(evalai_secrets["auth_token"]), "Content-Type": "application/json"},
            body=json.dumps({
                "submission": submission_data["submission"]["submission_id"],
                "challenge_phase": submission_data["submission"]["track_id"],
                "submission_status": "FINISHED",
                "result": json.dumps(submission_data["results"]),
                "stdout": "Legacy submission of an AlphaDrive team",
                "stderr": "",
                "environment_log": "",
                "metadata": "",
            })
        ).data)
        print(out)

        evalai_status = json.loads(manager.request(
            method="GET",
            url="{0}{1}{2}".format(evalai_secrets["api_server"], "/api/jobs/submission/", event["submission"]["submission_id"]),
            headers={"Authorization": "Bearer {}".format(evalai_secrets["auth_token"])},
        ).data).get("status", "").upper()

        print(submission_status, evalai_status)

    except:
        pass

    return submission_data
