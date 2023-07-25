# Running user submissions

With the Leaderboard cluster prepared and running, it is now time to prepare the submission pipeline. This includes everything between the arrival of the submission at the AWS SQS Queue and the start of its deployment in the Kubernetes cluster.

The user submissions can be described as a one-time processes that has a clear start and end conditions. As such, we can make use of the [Kubernetes Job](https://kubernetes.io/docs/concepts/workloads/controllers/job/) to achieve that task. The following sections will focus on how exactly has been the Kubernetes Job designed.

1. [Job overview](/docs/4_1_job_overview.md)
1. [Containers overview](/docs/4_2_containers_overview.md)