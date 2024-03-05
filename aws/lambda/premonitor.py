

def lambda_handler(event, context):

    return {
        "cluster": event["cluster"],
        "submission": {
            "submission_id": event["submission"]["submission_id"],
            "name": "monitor-{}".format(event["submission"]["submission_id"]),
            "challenge_id": event["submission"]["challenge_id"],
            "team_id": event["submission"]["team_id"],
            "track_id": event["submission"]["track_id"],
        },
        "parallelization": event["parallelization"],
        "aws": event["aws"],
        "evalai": event["evalai"]
    }
