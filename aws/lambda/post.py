import copy
import datetime
import json
import os
import time
import urllib3

import boto3

# aws resources
s3 = boto3.resource('s3')
dynamodb = boto3.resource('dynamodb')


def lambda_handler(event, context):
 
    out = copy.deepcopy(event)
    is_eligible, submission_data = out["is_eligible"], out["data"]

    def read_file_from_s3(bucket, file):
        try:
            obj = s3.Object(bucket, file)
            return obj.get()["Body"].read().decode('utf-8')
        except Exception as e:
            return ""

    bucket = s3.Bucket(event["aws"]["s3_bucket"])
    objs = list(bucket.objects.filter(Prefix="{}/containers-status".format(event["submission"]["submission_id"])))
    objs_name = [os.path.basename(o.key) for o in objs]
    objs_extension = [os.path.splitext(obj_name)[1] for obj_name in objs_name]

    if ".cancel" in objs_extension:
        submission_status = "CANCELLED"
    elif objs_extension.count(".done") == 3 * int(event["parallelization"]["workers"]):  # each job has 3 containers
        submission_status = "FINISHED"
    else:
        submission_status = "FAILED"

    submission_data["submission"]["submission_status"] = submission_status

    results = read_file_from_s3(event["aws"]["s3_bucket"], "{}/evalai/results.json".format(event["submission"]["submission_id"]))
    stdout = read_file_from_s3(event["aws"]["s3_bucket"], "{}/evalai/stdout.txt".format(event["submission"]["submission_id"]))
    stderr = "" if is_eligible else "You are not allowed to submit to this track. Please, run the qualifier track first."
    metadata = read_file_from_s3(event["aws"]["s3_bucket"], "{}/evalai/metadata.json".format(event["submission"]["submission_id"]))

    if submission_status == "FINISHED":
        # extract results
        assert results is not ""
        submission_data["results"] = {k.replace(" ", "_").lower(): str(v) for k,v in json.loads(results)[0]["accuracies"].items()}

        # update qualified team
        if bool(submission_data["qualifier"]["is_qualifying"]) and float(submission_data["results"]["driving_score"]) >= float(submission_data["qualifier"]["threshold"]):
            # the team is now qualified
            qualifier_table = dynamodb.Table(submission_data["aws"]["dynamodb_qualifier_table"])
            qualifier_table.put_item(Item={
                "team_id": submission_data["submission"]["team_id"],
                "track_codename": submission_data["qualifier"]["qualifying_to"],
                "submission_id": submission_data["submission"]["submission_id"]
            })


    pool_manager = urllib3.PoolManager()
    try:
        evalai_status = ""
        retries, MAX_RETRIES = 0, 5
        while submission_status != evalai_status and retries < MAX_RETRIES:
            out = json.loads(pool_manager.request(
                method="PUT",
                url="{}{}{}{}".format(submission_data["evalai"]["api_server"], "/api/jobs/challenge/", event["submission"]["challenge_id"], "/update_submission/"),
                headers={"Authorization": "Bearer {}".format(submission_data["evalai"]["auth_token"]), "Content-Type": "application/json"},
                body=json.dumps({
                    "submission": submission_data["submission"]["submission_id"],
                    "challenge_phase": submission_data["submission"]["track_id"],
                    "submission_status": submission_data["submission"]["submission_status"],
                    "result": results,
                    "stdout": stdout,
                    "stderr": stderr,
                    "environment_log": "",
                    "metadata": metadata,
                })
            ).data)
            print(out)

            evalai_status = json.loads(pool_manager.request(
                method="GET",
                url="{0}{1}{2}".format(submission_data["evalai"]["api_server"], "/api/jobs/submission/", event["submission"]["submission_id"]),
                headers={"Authorization": "Bearer {}".format(submission_data["evalai"]["auth_token"])},
            ).data).get("status", "").upper()
            retries += 1

            print(submission_status, evalai_status)

    except:
        pass

    # update submissions in the database
    submissions_table = dynamodb.Table(submission_data["aws"]["dynamodb_submissions_table"])
    submissions_table.update_item(
        Key={"team_id": submission_data["submission"]["team_id"], "submission_id": submission_data["submission"]["submission_id"]},
        UpdateExpression="SET submission_status = :s, end_time = :t, driving_score = :ds, route_completion = :rc, infraction_penalty = :ip, collisions_pedestrians = :cp, collisions_vehicles = :cv, collisions_layout = :cl, red_light_infractions = :rl, stop_sign_infractions = :ss, off_road_infractions = :or, route_deviations = :rd, route_timeouts = :rt, agent_blocked = :ab, yield_emergency_vehicle_infractions = :ev, scenario_timeouts = :st, min_speed_infractions = :ms",
        ExpressionAttributeValues={
            ":s":  submission_data["submission"]["submission_status"],
            ":t":  f"{datetime.datetime.now().strftime('%Y-%m-%d %T%Z')} {time.tzname[time.daylight]}",
            ":ds": submission_data["results"].get("driving_score", "-"),
            ":rc": submission_data["results"].get("route_completion", "-"),
            ":ip": submission_data["results"].get("infraction_penalty", "-"),
            ":cp": submission_data["results"].get("collisions_pedestrians", "-"),
            ":cv": submission_data["results"].get("collisions_vehicles", "-"),
            ":cl": submission_data["results"].get("collisions_layout", "-"),
            ":rl": submission_data["results"].get("red_light_infractions", "-"),
            ":ss": submission_data["results"].get("stop_sign_infractions", "-"),
            ":or": submission_data["results"].get("off-road_infractions", "-"),
            ":rd": submission_data["results"].get("route_deviations", "-"),
            ":rt": submission_data["results"].get("route_timeouts", "-"),
            ":ab": submission_data["results"].get("results.agent_blocked", "-"),
            ":ev": submission_data["results"].get("yield_emergency_vehicle_infractions", "-"),
            ":st": submission_data["results"].get("scenario_timeouts", "-"),
            ":ms": submission_data["results"].get("min_speed_infractions", "-")
        }
    )

    return submission_data
