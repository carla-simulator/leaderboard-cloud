# Cluster creation

Create the cluster and install the NVIIDA Device plugin

```bash
# Create the cluster
eksctl create cluster -f config/challenge-cluster.yaml --install-nvidia-plugin=false

# Install the NVIDIA Device plugin
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.13.0/nvidia-device-plugin.yml
```

This process can be checked by going to *CloudFormation* in AWS

To start the autoscaler, download the [most recent version](https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml) and change *<YOUR CLUSTER NAME>* near the end of the file with our own cluster name.

With that, just run it, using

```bash
kubectl apply -f config/cluster-autoscaler-autodiscover.yaml
```

Let's run a tst job to ensure the cluster is correctly set up.

```
kubectl apply -f tests/test-gpu-job.yaml
```

This should start a *busybox* job which will constantly use a GPU until stopped

# Deletion

To delete the cluster, use
```bash
eksctl delete cluster --region=us-east-2 --name=beta-leaderboard-20
```

and the job: 
```
kubectl delete -f tests/test-gpu-job.yaml
```

# Kubectl commands

To check the pods and nodes of the cluster
```
watch kubectl get nodes,pods -o wide
```

To check specific information about the pod
```
kubectl describe pod <POD-NAME>
```

For the autoscaler logs:
```
kubectl -n kube-system logs -f deployment.apps/cluster-autoscaler
```

To run commands inside a pod:
```
kubectl exec -n kube-system -it <POD-NAME> -- <command>