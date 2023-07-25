Welcome to the *leaderboard-cloud* repository. Here, users can find all the resources, steps and information about the infraestructure used by the CARLA Leaderboard's cloud. The aim is to have a clear open source, easy to understand pipeline that can be used to deploy either future versions of the official CARLA Leaderboard, or possible variations done by the users. While a minimum of cloud infraestructure is expected from the users, the docs are created so that a deep understanding of it isn't really needed.

As for the repositories structure, `aws`, `evalai` and `leaderboard` are the different sections of the cloud's implementation. While the first two are the same for any of the two Leaderboard version, the `leaderboard` folder explains the creation of the cluster, which has slight variations between versions, hence the `leaderboard_1.0` and `leaderboard_2.0` folders.

Below is a summary of the different topics that will be discussed for a succesful implementation of the cloud infraestructure.

1. [Install prerequisites](/docs/1_prerequisites.md)
1. [Infrastructure overview](/docs/2_overview.md)
1. [Leaderboard cluster](/docs/3_leaderboard_cluster.md)
    - [Custom AMI](/docs/3_1_creation_of_the_ami.md)
    - [Configuration file](/docs/3_2_cluster_configuration.md)
    - [Creation of the cluster](/docs/3_3_cluster_creation.md)
    - [Saving the logs](/docs/3_4_logging_to_cloudwatch.md)
    - [Manage cluster access](/docs/3_5_cluster_access.md)
1. [Running user submissions](/docs/4_running_user_submissions.md)
    - [Job overview](/docs/4_1_job_overview.md)
    - [Containers overview](/docs/4_2_containers_overview.md)
1. [AWS interface](/docs/5_aws_interface.md)
    - [Storage services](/docs/5_1_storage_services.md)
    - [Deployment services](/docs/5_2_automatic_job_deployment.md)
1. [EvalAI Frontend](docs/6_frontend.md)
1. [Useful Commands](docs/x_useful_commands.md)

_NOTE: These docs assume that you are using Linux and that all commands are run from either of the leaderboard folders.

<!--
- 0) Prerequisites
- 1) Diagram
- 2) Cluster creation
  · Base AMI
  · Design of the cluster configuration file 
    - Node groups
    - Cluster permissions
  · Cluster creation and addition of logging mechanisms
  · Granting other users access
- 3) CARLA Job
  · Paralellization of the routes
  · Explanation of the `run_X.sh` files
  · Detection of crashes and automatic resume
- 4) Automatic submissions
  · SQS Queue
  · EventBridge
  · Step Function
  · Frontend
- 5) Deployment
  · Package creation
  · Docker creation
-->