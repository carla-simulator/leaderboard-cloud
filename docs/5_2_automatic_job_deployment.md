# Automatic Job deployment

The last pipeline that needs to be discussed is the automatic deployment of the submission Job onto the cluster. This starts with the of a message to an SQS Queue from EvalAI, and ends in the creation of a Job in the cluster.

As a general overview, the pipeline starts, as previously mentioned, with an [AWS SQS Queue](https://aws.amazon.com/sqs/). The message in the queue is sent to an [AWS Step Function](https://aws.amazon.com/step-functions/) using an [AWS Event Bridge Pipe](https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-pipes.html), and it is that Step Function that automatically parametrizes and starts the Kubernetes Job.

While up until this point, both Leaderboard have been treated as independent pipelines, this is not going to be the case from now on. From the users point of view, there is only one challenge, which has 4 phases, 2 for the Leaderboard 1.0 and another 2 for the Leaderboard 2.0, and it is this pipeline that separates the submission, sending them either of the two clusters. Specifically, this is done in the Step Function.

The following sections explain in a more detailed manner how these AWS elements work, and how to set them up.

## SQS Queue and Event Bridge

Starting with the SQS Queue, these are fully managed queues that allow users to send, store and receive messages from other services and applications. This is the point of communication from the frontend to the backend and as such, this element was very dependent of the frontend's infrastructure.

For the Leaderboard case, this queue is just used as a message receiving tool, as once received, the Event Bridge Pipe immediately sends it onto the Step Function, removing it from the queue.

## Step Function and Lambda

With a message describind the details about a user's submission, it is now time to make use of the Step Function's visual workflow capabilities to start programming the launch of the Kubernetes Job. While some of the common actions can be directly created from the Step Function, it can also use [AWS Lambda](https://aws.amazon.com/lambda/), a serveless service that runs any code created by the user.

Below is a diagram of the Step Function blocks.

<center>
<img style="width:100em" src="{{ "/docs/images/step_function_diagram.png" | prepend: site.baseurl }}"/>
<br>
</center>

The Step Function starts with a Lambda called *PreEKS*, which can be found [here](/aws/lambda/pre.py). While the EvalAI message contains all the information needed to run the submission, it can provide more information about it by making a request to the EvalAI's API. Information such as the participant team's id or name can be extracted with it, which will be used in the next step, when the submission is added into the DynamoDB database.

The next block is a *Choice* one, and checks the submission status to avoid running it if the user has cancelled it, skipping its simulation, but no other step. This shouldn't be the case, as the Step Function is almost immediately run after the submission is created, but it adds robustness in case of a failure.

If no issues have arisen, the next step is to run the Kubernetes Job. To decide on which cluster to run it, a *Choice* block has been added, which the frontend's phase to extract the cluster and the track. This is possible due to the strict naming of the 4 EvalAI phases (specifically their *codename*, which is the internal naming). For example, if a submission is done to the `leaderboard-10-SENSORS` phase, the name can be divided into `leaderboard-10`, indicating the cluster, and `SENSORS`, indicating the track.

The Step Function provides an *EKS Run Job* block to easily run the Kubernetes Job from EKS. In here, the *API Parameters* will have to be filled with the Job's configuration file, in json format. To transform it from *yaml* to *json*, the [yaml2json.py](/utils/yaml2json.py) utility script available in this repo can be used. The results are [this file](/leaderboard_1.0/jobs/carla-benchmark-step-function-job.json) for the Leaderboard 1.0, and [this one](/leaderboard_2.0/jobs/carla-benchmark-step-function-job.json) for the Leaderboard 2.0.

Additionally, make sure the *Wait for task to complete* (just below the *API Parameters*), option is ticked. In case of reaching the `backoffLimit`, the *EKS Run Job* block will result in failure, exitting the Step Function's execution. A try-catch exception has been added to both blocks, stopping this and allowing the proper handling of failing submissions.

Once the job has finished, the Step Function removes it, as by default it stays there forever. Then, the *PostEKS* Lambda is triggered, with its code available [here](/aws/lambda/post.py). This lambda is responsible for parsing and sending a request to the EvalAI API with the final submission data, including the metrics that will be shown in the Leaderboard.

The last step of the Step Function is to add the previously calculated results onto their respective databases.


## Creation of the pipeline

The first step is to create the IAM Roles that these services will need to access the different components. While these are automatically created along with the services themselves, we found it more intuitive to have create them separately, and add them to the services once they are created.

All the files describing these policies are placed in the [aws/policies](/aws/policies/) folder, and can be created using AWS CLI with:
```bash
bash create-aws_policies.sh
```

The created policies have the following permissions:
- Event Bridge Pipe policy: search and delete messages in the SQS Queue, and start the Step Function
- Lambdas policy: read the secrets and put events in S3
- Step Function policy: put items in the DynamoDB database and x-ray actions to all resources

One important note about these policies is that they have been purposely left open without specifying the service names, to ease the change of service names, such as when moving from staging to production. However, this makes the policies more open then needed as, for example, the EventBridge Pipe can start any Step Function, not just the Leaderboard's one, which might not be desired in some use-cases.

Also, remember that the StepFunction policy had already been referenced at the cluster configuration so that it has admin access when accessing it.

Now, onto the services, starting with the Lambda functions. Their creation is quite straightforward. Go to the `Lambda` section and `Create function`. Name the Lambda function, choose the *Python3.10* Runtime, use the execution role to `LeaderboardLambdaRole`, and create the function. We want to create two Lambda for the Leaderboard, one name *PreEKS*, with the code available [here](/aws/lambda/pre.py), and another one called *PostEKS*, which [this code](/aws/lambda/post.py).

To create the SQS Queue, go to the `Simple Queue Service` service in AWS and click on `Create queue`. Due to the simple use of this queue, no real customization is needed, so the default values as good enough. Give it a name, such as `leaderboard`, and click on `Create queue`.

As the EventBridge will require to specify the linked Step Function, let's create the Step Function first. Go to the `Step Functions` service and click on `Create state machine`. Select the *Standard* option and click `Next`. The new section is used to create the Step Function via blocks, which can be a great tool when starting a new one. In our case, the Step Function is already built, so move onto the next section and paste the contents in the [step_function.json](/aws/step_function/step_function.json) file onto the code snippet, directly creating all the Step Function at once. To finish, give it a name, such as `leaderboard`, and use the existing role `LeaderboardStepFunctionRole`.

Moving onto the Event Bridge, go to `Pipes` and `Create pipe`. In the *Source* section, select the previously created SQS Queue. Make sure that the additional settings have a Batch Size of 1 (should be the default value), or the Step Function will fail to execute. For the *Target* section, select the Step Function, go to the `Target Input Transformer` and add the following transformer (in the middle box).
```json
{
  "challenge_pk": <$.body.challenge_pk>,
  "phase_pk": <$.body.phase_pk>,
  "submission_pk": <$.body.submission_pk>,
  "submitted_image_uri": <$.body.submitted_image_uri>
}
```

There is no need to add any *Filtering* or *Enrichment* options. To add the Pipe's role, go to *Pipe Settings* and *Use existing role*.
