import base64
import copy
import json
import os
import urllib3

import boto3
import botocore.exceptions

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
 
    s3 = boto3.resource('s3')
    bucket = s3.Bucket(event["aws"]["s3_bucket"])
    objs = list(bucket.objects.filter(Prefix="{}/containers-status".format(event["submission"]["submission_id"])))
    objs_name = [os.path.basename(o.key) for o in objs]
    objs_extension = [os.path.splitext(obj_name)[1] for obj_name in objs_name]

    if ".cancel" in objs_extension:
        submission_status = "CANCELLED"
    elif objs_extension.count(".done") == 9:
        submission_status = "FINISHED"
    else:
        submission_status = "FAILED"

    results = s3.Object(event["aws"]["s3_bucket"], "{}/evalai/results.json".format(event["submission"]["submission_id"]))
    results = results.get()["Body"].read().decode('utf-8')

    stdout = s3.Object(event["aws"]["s3_bucket"], "{}/evalai/stdout.txt".format(event["submission"]["submission_id"]))
    stdout = stdout.get()["Body"].read().decode('utf-8')

    metadata = s3.Object(event["aws"]["s3_bucket"], "{}/evalai/metadata.json".format(event["submission"]["submission_id"]))
    metadata = metadata.get()["Body"].read().decode('utf-8')

    all_submission_data = copy.deepcopy(event)
    all_submission_data["submission"]["submission_status"] = submission_status
    all_submission_data["submission"]["result"] = results
    all_submission_data["submission"]["stdout"] = stdout
    all_submission_data["submission"]["stderr"] = ""
    all_submission_data["submission"]["environment_log"] = ""
    all_submission_data["submission"]["metadata"] = metadata

    evalai_secrets = get_secret(secret_id="evalai")
    
    manager = urllib3.PoolManager()
    out = json.loads(manager.request(
        method="PUT",
        url="{}{}{}{}".format(evalai_secrets["api_server"], "/api/jobs/challenge/", event["submission"]["challenge_id"], "/update_submission/"),
        headers={"Authorization": "Bearer {}".format(evalai_secrets["auth_token"]), "Content-Type": "application/json"},
        body=json.dumps({
            "submission": all_submission_data["submission"]["submission_id"],
            "challenge_phase": all_submission_data["submission"]["track_id"],
            "submission_status": all_submission_data["submission"]["submission_status"],
            "result": all_submission_data["submission"]["result"],
            "stdout": all_submission_data["submission"]["stdout"],
            "stderr": all_submission_data["submission"]["stderr"],
            "environment_log": all_submission_data["submission"]["environment_log"],
            "metadata": all_submission_data["submission"]["metadata"],
        })
    ).data)

    return all_submission_data
