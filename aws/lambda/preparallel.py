

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
            "cluster": event["cluster"],
            "submission": {
                "submission_id": event["submission"]["submission_id"],
                "name": "submission-{}-{}".format(event["submission"]["submission_id"], worker_id + 1),
                "resume": event["submission"]["resume"],
                "submitted_image_uri": event["submission"]["submitted_image_uri"],
                "track_codename": event["submission"]["track_codename"],
                "subset": subset
            },
            "parallelization": {
                "worker_id": str(worker_id + 1),
                "gpus": event["parallelization"]["gpus"] 
            },
            "aws": {
                "s3_bucket": event["aws"]["s3_bucket"],
            }
        })

    return out_
