# Leaderboard cluster

As explained in the previous sections, the first topic to discuss in depth is the design and implementation of the Leaderboard cluster.

Using `eksctl`, a cluster can be created inside the AWS infrastructure, where the rest of the AWS tools will have access to it. To define the specific of the cluster, eksctl requires a configuration file with information about the cluster instances, their permissions, and setup. 

With that, the bare bones of the cluster will be prepared. However, there are still several items missing to be created, for a smoother usage of the cluster.

Note that both versions of the Leaderboard will each have their own cluster, and this was a conscious choice to avoid blocking all the submission pipeline in the case of an unforseen failure.

1. [Custom AMI](/docs/3_1_creation_of_the_ami.md)
1. [Configuratioon file](/docs/3_2_cluster_configuration.md)
1. [Creation of the cluster](/docs/3_3_cluster_creation.md)
1. [Saving the logs](/docs/3_4_logging_to_cloudwatch.md)
1. [Manage cluster access](/docs/3_5_cluster_access.md)
