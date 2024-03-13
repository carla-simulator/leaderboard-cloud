

def lambda_handler(event, context):

    return {
        "cluster": event["data"]["cluster"],
        "submission": {
            "submission_id": event["data"]["submission"]["submission_id"],
            "name": "monitor-{}".format(event["data"]["submission"]["submission_id"]),
            "challenge_id": event["data"]["submission"]["challenge_id"],
            "team_id": event["data"]["submission"]["team_id"],
            "track_id": event["data"]["submission"]["track_id"],
        },
        "aws": event["data"]["aws"],
        "evalai": event["data"]["evalai"]
    }
