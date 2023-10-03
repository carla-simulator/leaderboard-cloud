# Infraestructure overview

Before explaining all of the different components of the infrastructure, below is a diagram showing the relation between all of them.

![CARLA Modules](/docs/images/overview_diagram.png)

The Leaderboard frontend is created as a challenge part of the EvalAI platform. Users can apply to that challenge and submit their dockers using the EvalAI CLI. EvalAI then connects with the Leaderboard backend in two ways.

First of all, the docker is automatically uploaded into AWS ECR for storage purposes. Additionally, EvalAI has an AWS SQS Queue linked with the challenge, where it sends a message with some of the user's submission information.

From the backend point of view, an AWS EventBridge Pipe has been created, which detects when a new message arrives to the AWS SQS Queue, retrieves it, and sends it to a AWS Step Function. That Step Function then gets more data about the submission, and saves it onto our database, DynamoDB. Then, it creates a Kubernetes Job to run the submission in the cluster, and once it finishes, sends the results to the EvalAI frontend making use of their Rest API, as well as saving the results into the database and AWS S3.

Each job contains 3 types of containers, all of which are downloaded from AWS ECR. The `simulator` and `agent` containers are responsible for running the Leaderboard submissions while the `logcopy` monitors the output and results of the previous two, periodically updating EvalAI, AWS S3 and AWS DynamoDB.

An additional configuration of the cluster is the use of [FluentD](https://www.fluentd.org/) to monitor the 3 container types to send their output to AWS Cloudwatch, as well as a [cluster autoscaler](https://github.com/kubernetes/autoscaler), that automatically scales the number of available instances according to the demand.

From here, the following sections will be explained in detail one by one, starting from the most inner part of the infrastructure, the cluster, and expanding outwards into the automatic deployment of the submissions, saving its results into a database, and many others.