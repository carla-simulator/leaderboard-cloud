# Creation of the cluster

With the configuration file ready, it is time to create the cluster on AWS. To do so, run the `eksctl` command
```bash
eksctl create cluster -f config/leaderboard-cluster.yaml --install-nvidia-plugin=false
```

This command can take up to 30 minutes. Go to AWS CloudFormation for more details of the cluster status. This is also useful when deleting the cluster, as the CLI commands tends to finish before the complete removal of the cluster.

### NVIDIA Device Plugin

Adding to the configuration done at the base AMI, for the NVIDIA GPUs to be detected as available resources by the cluster, a plugin needs to be installed. It is publicly available on the NVIDIA repositories. Make sure to install the latest version by checking the [Releases](https://github.com/NVIDIA/k8s-device-plugin/releases) section. In this case:

```bash
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.14.0/nvidia-device-plugin.yml
```

This plugin is a DaemonSet, which means that it is a process that Kubernetes will automatically run in all instances.

### Cluster Autoscaler

The next step is to add the [autoscaler](https://github.com/kubernetes/autoscaler) resource to the cluster. This tool allows the cluster to change the amount of available running instances between a minimum and maximum amount, automatically creating and deleting them depending on the need of the cluster. While this means that submissions won't be able to immediately start, as the instance will have to be initialized, the amount of unused instances gets drastically removed, along with the cost of keeping them running.

Download the [most recent version](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml) and change *<YOUR CLUSTER NAME>* near the end of the file with the cluster's name.

The ones used by these docs are located [here](/leaderboard_1.0/config/cluster-autoscaler-autodiscover.yaml) for the Leaderboard 1.0, and [here](/leaderboard_1.0/config/cluster-autoscaler-autodiscover.yaml) for the Leaderboard 2.0, which can then be applied to the cluster with the command
```bash
kubectl apply -f config/cluster-autoscaler-autodiscover.yaml
```

### (Optional) Test the cluster

To ensure that all of the previous steps have been correctly apllied, here is a quick test to do, taken from [this section](https://github.com/NVIDIA/k8s-device-plugin#running-gpu-jobs) in the NVIDIA Device plugin.

Start a Kubernetes Pod by running
```bash
kubectl apply -f ../tests/test-gpu-job.yaml
```

As this Pod requires a GPU, the autoscaler should detect it and create a new instance. Monitor the amount of instances at the cluster with
```bash
watch kubectl get nodes,pods
```

If everything works, you will see that while the cluster starts with only 1 node, a new one will be automatically created after several minutes. Once the instance is ready, the Pod should rapidly complete.

To get more information about the pod, these commands can be used:
```bash
# Get a general description of the pod
kubectl describe gpu-pod

# Get the pod logs
kubectl logs gpu-pod
```

After that, delete the job
```bash
kubectl delete -f ../tests/test-gpu-job.yaml
```
and the autoscaler will automatically remove the previously created pod, as it is no longer necessary. Again, you might to wait several minutes before the autoscaler removed the instance
