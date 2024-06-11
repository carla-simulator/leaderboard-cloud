import re


def lambda_handler(event, context):

    name = "{}-{}-{}-monitor".format(
        # only lowercase alphanumeric characters plus - and .
        re.sub('[^0-9a-z-.]+', "?", event["data"]["submission"]["team_name"].lower().replace("_", "-").replace(" ", "-")),
        event["data"]["submission"]["track_codename"].lower().replace("_", "-"),
        event["data"]["submission"]["submission_id"]
    )

    return {
        "cluster": event["data"]["cluster"],
        "submission": {
            "submission_id": event["data"]["submission"]["submission_id"],
            "name": name,
            "challenge_id": event["data"]["submission"]["challenge_id"],
            "team_id": event["data"]["submission"]["team_id"],
            "track_id": event["data"]["submission"]["track_id"],
            "resume": event["data"]["submission"]["resume"]
        },
        "aws": event["data"]["aws"],
        "evalai": event["data"]["evalai"]
    }
