import base64
import copy
import datetime
import json
import os
import time
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
 
    def read_file_from_s3(bucket, file):
        try:
            obj = s3.Object(bucket, file)
            return obj.get()["Body"].read().decode('utf-8')
        except Exception as e:
            return ""

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

    submission_data = copy.deepcopy(event)
    submission_data["submission"]["submission_status"] = submission_status
    submission_data["submission"]["end_time"] = f"{datetime.datetime.now().strftime('%Y-%m-%dT%T%Z')}{time.tzname[time.daylight]}"

    results = read_file_from_s3(event["aws"]["s3_bucket"], "{}/evalai/results.json".format(event["submission"]["submission_id"]))
    stdout = read_file_from_s3(event["aws"]["s3_bucket"], "{}/evalai/stdout.txt".format(event["submission"]["submission_id"]))
    metadata = read_file_from_s3(event["aws"]["s3_bucket"], "{}/evalai/metadata.json".format(event["submission"]["submission_id"]))

    if submission_status == "FINISHED":
        # Extract results
        assert results is not ""
        submission_data["results"] = {k.replace(" ", "_").lower(): str(v) for k,v in json.loads(results)[0]["accuracies"].items()}

    evalai_secrets = get_secret(secret_id="evalai")
    manager = urllib3.PoolManager()
    try:
        out = json.loads(manager.request(
            method="PUT",
            url="{}{}{}{}".format(evalai_secrets["api_server"], "/api/jobs/challenge/", event["submission"]["challenge_id"], "/update_submission/"),
            headers={"Authorization": "Bearer {}".format(evalai_secrets["auth_token"]), "Content-Type": "application/json"},
            body=json.dumps({
                "submission": submission_data["submission"]["submission_id"],
                "challenge_phase": submission_data["submission"]["track_id"],
                "submission_status": submission_data["submission"]["submission_status"],
                "result": results,
                "stdout": stdout,
                "stderr": "",
                "environment_log": "",
                "metadata": metadata,
            })
        ).data)
    except:
        pass

    return submission_data
