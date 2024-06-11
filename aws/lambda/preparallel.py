import math
import re


def lambda_handler(event, context):

    routes = int(event["data"]["submission"]["routes"])
    workers = min(routes, int(event["data"]["cluster"]["parallelization_workers"]))
    step = float(routes) / float(workers)
    routes_subset = ["{}-{}".format(math.ceil(i*step), math.ceil((i+1)*step) -1)  for i in range(workers)]

    out_ = []
    for worker_id, subset in enumerate(routes_subset):
        name = "{}-{}-{}-worker{}".format(
            # only lowercase alphanumeric characters plus - and .
            re.sub('[^0-9a-z-.]+', "?", event["data"]["submission"]["team_name"].lower().replace("_", "-").replace(" ", "-")),
            event["data"]["submission"]["track_codename"].lower().replace("_", "-"),
            event["data"]["submission"]["submission_id"],
            worker_id + 1
        )

        out_.append({
            "cluster": event["data"]["cluster"],
            "submission": {
                "submission_id": event["data"]["submission"]["submission_id"],
                "name": name,
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
