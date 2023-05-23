# Creation of the cluster

Now it is finally time to create the cluster on AWS. To do so, `eksctl` will be used. While all of the cluster configuration can be passed through the arguments, it is recommended to add them all into a YAML files. The one used by the Leadeboard is available [here](../config/leaderboard-cluster.yaml).

However, before executing it, make sure the cluster is linked with the AMI created on the previous section, located at `nodeGroups[submission-worker].ami`. For more details about the cluster configuration, check [this docs](3_1_understanding_the_cluster_configuration). Then, start the cluster creation with the following command:

```bash
eksctl create cluster -f config/leaderboard-cluster.yaml --install-nvidia-plugin=false
```

> Take into account that the cluster creation can take up to 30 minutes. Go to AWS `CloudFormation` for more details of the cluster status. This is also useful when deleting the cluster, as the CLI commands tends to finish before the complete removal of the cluster.

### NVIDIA Device Plugin

Adding to the configuration done at the base AMI, for the NVIDIA GPUs to be detected as available resources by the cluster, a plugin needs to be installed. It is publicly available on the NVIDIA repositories. Make sure to install the latest version by checking the [Releases](https://github.com/NVIDIA/k8s-device-plugin/releases) section. In this case:

```
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.13.0/nvidia-device-plugin.yml
```

This plugin is a DaemonSet, which means that it is a process that Kubernetes will automatically make sure that it is available and running in all instances.

### Cluster Autoscaler

The next step is to add the autoscaler resources to the cluster. This tool allows the cluster to oscilate between a minimum and maximum amount of instances running in parallel, automatically creating / deleting them depending on the amount of resources used by it. While having the need to always start a machine every time a new one is needed is definitely a downside, the amount of money saved by removing unused machine is definitely worth the implementation of this tool.

Download the [most recent version](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml) and change *<YOUR CLUSTER NAME>* near the end of the file with the cluster's name.

The one used by these docs is located [here](../config/cluster-autoscaler-autodiscover.yaml), which can then be applied to the cluster with the command
```bash
kubectl apply -f config/cluster-autoscaler-autodiscover.yaml
```

### (Optional) Test the cluster

To ensure that all of the previous steps have been correctly apllied, here is a quick test to do, taken from [this section](https://github.com/NVIDIA/k8s-device-plugin#running-gpu-jobs) in the NVIDIA Device plugin.

Start a Kubernetes Pod by running
```bash
kubectl apply -f tests/test-gpu-job.yaml
```

As this Pod requires a GPU, the autoscaler should detect it and create a new instance automatically.

Monitor the amount of instances created at the cluster with
```bash
watch kubectl get nodes,pods
```

If everything works, you will see that while the cluster starts with only 1 node, a new one will be automatically created after several minutes. Once the instance is ready, the Pod should rapidly complete.

To get more information about the pod, these commands can be usedun by getting its logs.
```bash
# Get a general description of the pod
kubectl describe gpu-pod

# Get the pod logs
kubectl logs gpu-pod
```

After that, delete the job
```bash
kubectl delete -f tests/test-gpu-job.yaml
```
and the autoscaler will automatically remove the previously created pod, as it is no longer necessary.

In case of failure, check the [useful commands](x_useful_commands.md) section to debug it.
