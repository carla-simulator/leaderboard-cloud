# Useful commands

This section is a recollection of the commands that are the most used during testing. This helps the testing by having a centralized location were the common commands are available for copying.

# Cluster creation and deletion

To create the cluster, follow these commands:
```bash
# Create the cluster 
eksctl create cluster -f config/leaderboard-cluster.yaml --install-nvidia-plugin=false
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.14.0/nvidia-device-plugin.yml
kubectl apply -f config/cluster-autoscaler-autodiscover.yaml
kubectl apply -f config/fluentd.yaml
```

And to delete it, choose on the two options below
```bash
# Delete the Leaderboard 1.0 cluster
eksctl delete cluster --region=us-west-1 --name=leaderboard-10
# Delete the Leaderboard 2.0 cluster
eksctl delete cluster --region=us-west-1 --name=leaderboard-20
```

# Cluster access

Below are the commands used when users want to have access to specific clusters
```bash
# Accessing the Leaderboard 1.0 cluster (for the 2nd time)
aws eks update-kubeconfig --region us-west-2 --name leaderboard-10 --alias l1
kubectl config use-context l1
# Accessing the Leaderboard 2.0 cluster (for the 2nd time)
aws eks update-kubeconfig --region us-west-2 --name leaderboard-20 --alias l2
kubectl config use-context l2

# Changing the alias (for the cluster creator only)
kubectl config rename-context $(kubectl config current-context) l2

# Show all available contexts
kubectl config get-contexts

# Remove context
kubectl config delete-context l2-staging
```

# kubectl

For interaction with the cluster, create and delete elements with
```bash
kubectl apply -f <YAML-FILE>
kubectl delete -f <YAML-FILE>
```

Get a table with some of the cluster elements
```bash
kubectl get pods,nodes -n <NAMESPACE>
```

The most common elements to search for are *pods*, *nodes*, *jobs*, *sa* (service accounts).


To get more information about an element
```bash
# Describe it
kubectl describe <type/NAME> -n <NAMESPACE>       # For example 'kubectl describe pod/submission-id-19345'

# Check its logs
kubectl logs <type/NAME> -n <NAMESPACE>        # For example 'kubectl logs pod/submission-id-19345'
```

To execute a command in a running pod
```bash
kubectl exec -n <NAMESPACE> -it <type/NAME> -- <COMMAND>
```

To enter it, execute the previous line with the `/bin/bash` COMMAND

# Others 

To enter an instance through ssh
```bash
# SSH into a machine
ssh -i <private-key-file> ubuntu@<public-ip>
```

To get the kubelet status and logs
```bash
systemctl status kubelet
journalctl -xe --unit kubelet
```

To get the containerd status, logs and configuration
```bash
systemctl status containerd
journalctl -xe --unit containerd
containerd config dump
```
