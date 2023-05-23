So, the CARLA Leaderboard 1.0 it is. Great choice indeed. Here is a summary of the different topics that will be discussed for a succesful implementation of the cloud infraestructure.

1. [Install prerequisites](docs/1_prerequisites.md)
1. [Creation of the base AMI](docs/2_creation_of_the_base_ami.md)
1. [Creation of the cluster](docs/3_creation_of_the_cluster.md)
    - [Understanding the cluster configuration](docs/3_1_understanding_the_cluster_configuration.md)
    - [Granting other users access to the cluster](docs/3_2_granting_cluster_access.md)
1. [Adding logging to Cloudwatch](docs/4_logging_results_to_cloudwatch.md)
1. [Automatic job deployment](docs/5_step_functions.md)
1. [EvalAI Frontend](docs/6_frontend.md)
1. [Useful Commands](docs/x_useful_commands.md)

The general structure of these docs is to start with the core part of the cluster, that being the Kubernetes Job that is responsible of running the CARLA server and Leaderboard. From there, start expanding to the rest of the features that wrap around it, allowing it to be automatically run when a submission is detected in the frontend, saving the logs and results into a database...

_NOTE: These docs assume that you are using Linux and that all commands are run from this folder
