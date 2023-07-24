# Running user submissions

With the Leaderboard cluster prepared and running, it is now time to start using it as by default, the only task that the cluster performs is the autoscaler monitoring. The use case of the cluster is to run user submissions, which can be describes as one-time processes that have a clear start and end conditions.

As such, we can make use of the [Kubernetes Job](https://kubernetes.io/docs/concepts/workloads/controllers/job/) to achieve that task. The following sections will focus on the user's submission job, starting Leaderboard submissions.

1. [Job overview](docs/4_1_job_overview)   <!--  Overview of the Job, and parallelization of the routes -->
1. [Containers overview](docs/4_2_containers_overview) <!-- injection of the private contents Workings of the run_carla and run_leaderboard and run_logcopy -->
1. [Parametrization of the variables](docs/4_3_parametrizatio)
