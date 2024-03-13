

def lambda_handler(event, context):

    # TODO: Compute this based on the total amount of routes and the desired number of workers.
    routes_subset = [
        "0-4",
        "5-9",
        "10-14",
        "15-19"
    ]

    out_ = []
    for worker_id, subset in enumerate(routes_subset):
        out_.append({
            "cluster": event["data"]["cluster"],
            "submission": {
                "submission_id": event["data"]["submission"]["submission_id"],
                "name": "submission-{}-{}".format(event["data"]["submission"]["submission_id"], worker_id + 1),
                "resume": event["data"]["submission"]["resume"],
                "submitted_image_uri": event["data"]["submission"]["submitted_image_uri"],
                "track_codename": event["data"]["submission"]["track_codename"],
                "subset": subset
            },
            "parallelization": {
                "worker_id": str(worker_id + 1),
            },
            "aws": {
                "s3_bucket": event["data"]["aws"]["s3_bucket"],
            }
        })

    return {
        "cluster_id": event["data"]["cluster"]["id"],
        "map": out_
    }
