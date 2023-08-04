import boto3
import botocore
import copy

def lambda_handler(event, context):

    submission_data = copy.deepcopy(event)
    s3 = boto3.client('s3')
    try:
        print("HELLO")
        s3.head_object(Bucket=event["aws"]["s3_bucket"], Key='{}/using-ros-agent.txt'.format(event["submission"]["submission_id"]))
        print("HELLO2")
        submission_data["submission"]["using_ros_agent"] = True
        print("HELLO3")
    except botocore.exceptions.ClientError as e:
        print("HELLO4")
        pass

    return submission_data
