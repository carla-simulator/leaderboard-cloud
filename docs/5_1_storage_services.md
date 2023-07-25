# AWS Storage services

AWS provides a huge amount of possible storage services, depending on the type of data, logging and future usability. This backend will be using for elements, explained in the following section

## Cloudwatch

The first service is [AWS Cloudwatch](https://aws.amazon.com/cloudwatch/), used to collect and visualize real-time logs. It makes use of *Log groups* to separate and categorize the different loggings. This repository uses two *Log groups*, `leaderboard-10` and `leaderboard-20` , one for each Leaderboard version. This logs are created using FluentD, which has been explained in the previous section [Saving the logs](/docs/3_4_saving_the_logs.md).

## S3

[AWS S3](https://aws.amazon.com/s3/) is an object storage service capable of storing any type and works very similar to a normal folder in any OS. S3 is divided into Buckets, and several are used by the Leaderboard.

For the main pipeline, and similarly to Cloudwatch, one bucket is used for each Leaderboard, named `leaderboard-10` and `leaderboard-20`. These contain all the results and data produced by each submission, which are stored inside a folder and identified by their EvalAI's ID. A reminder that this information includes the outputs all the job docker's, agent results and its parsing onto EvalAI format, as well as the shared volume used to communicate between dockers.

Additionally, the `leaderboard-public-contents` and `leaderboard-private-contents` buckets store the official CARLA packages from which the used dockers are created. The public ones can be shared with the Leaderboard users with a permanent link to its S3 location, and the private contents have all the packages for safe keeping. Note that the 

## Elastic Container Registry

While S3 stores files, AWS also provides the [AWS Elastic Container Registry](https://aws.amazon.com/ecr/) (ECR) which can be used to store docker containers. This service stores two types of dockers. Firstly, EvalAI sends all the submission dockers to ECR, and these are the only ones that had to be placed in the `us-east-1` AWS region, due to technical problems with their infrastructure. The rest of the dockers are located in the `us-west-2` region, as the other services, and are the docker images of the `simulator`, `agent` and `logcopy` part of the Kubernetes Job of both Leaderboards.

## DynamoDB

The next storing service used is [AWS DynamoDB](https://aws.amazon.com/pm/dynamodb/?trk=b3d144cd-963d-4a7c-9ebc-1a72f3b55ee5&sc_channel=ps&ef_id=Cj0KCQjw5f2lBhCkARIsAHeTvlh5lDZ41cw1RbF6tK9EGryQbzAAvlGVAQ71bXZXpHexcJ0hR789aPMaAu8iEALw_wcB:G:s&s_kwcid=AL!4422!3!588732065478!p!!g!!amazon%20web%20services%20dynamodb!16395977425!136814977187), a fully managed NoSQL database that is excellent when the majority of its queries will be done using either one or two keys at most. The rest of the keys can still be used as queries, but its performance and pricing and much worse when compared to the two primary keys.

Two databases have been created and are mainly used to store all the information about the submissions created by the users. This includes, among others, the metric scores, the submission's id and phase along with its start and end time, and participating team's name and id.

Following the pattern of the previous services, these two databases are once for each Leaderboard and named as `leaderboard-10` and `leaderboard-20`. For primary keys used, the *Partition Key* is the `team-id`, and for the *Sort Key*, the `submission-id`. While these keys can have repeated values, the elements of the database are limited to a unique *Partition Key* and *Sort Key* combination.

## Secrets

The last service used is the [Secrets Manager](https://aws.amazon.com/secrets-manager/), a service meant to help with the management of secret contents such as API keys, credentials and others. While not its official usage, its nature makes it a great tool to store parameters that require frequent changing during testing, hardcoded values present in the pipeline, or to expose the value of some key variable.

As such the use-case of the Secrets can be quite diverse and the Leaderboard backend makes use of four, two for EvalAI, and one for each the parameters of each Leaderboard version.

Starting with EvalAI, the `evalai` secret stores the authentication token needed when doing a request to its API, as well as its server URL. The `evalai-tracks` is used to link the *id* of the phases with their respective *codename*. This is useful because in our case, the *codename* is used to extract the submission's Leaderboard version and track, but the message sent by EvalAI makes of of its *id*.

As for the Leaderboard secrets, let's start with the *name*, *endpoint* and *certificate_authority*. These three values are used by the Step Function to know to which cluster to send the submissions. To get these values, navigate to the *Elastic Kubernetes Service* section and select on a cluster. The other three elements in this secret are *simulator_image*, *leaderboard_image* and *logcopy_image*, which store the ECR location of the images used by the Kubernetes Job. The last three elements are the *s3_bucket*, *dynamodb_submissinons_table* and *cloudwatch_log_group*, each of which being the respective names of the AWS services.
