# Useful commands

Here is a recollection of some useful commands to be used

### EKSCTL

```bash
"""
General
"""
eksctl create cluster -f <YAML-FILE> --install-nvidia-plugin=false
eksctl delete cluster --region=<CLUSTER-REGION> --name=<CLUSTER-NAME>

# As an example
eksctl create cluster -f config/leaderboard-cluster.yaml --install-nvidia-plugin=false
eksctl delete cluster --region=us-east-2 --name=beta-leaderboard-20
```

### Kubectl

```bash
"""
General
"""
kubectl apply -f <YAML-FILE>
kubectl delete -f <YAML-FILE>

"""
Nodes
"""
kubectl get nodes -o wide
kubectl describe node <NODE-NAME>

"""
Pods
"""
kubectl get pods -o wide -n <NAMESPACE>
kubectl logs -n <NAMESPACE> <POD-NAME>
kubectl exec -n <NAMESPACE> -it <POD-NAME> -- <COMMAND>
```

### Instance

```bash
"""
SSH
"""
ssh -i <private-key> ubuntu@<public-ip>

"""
Instance commands
"""
# Get the kubelet status and logs
systemctl status kubelet
journalctl -xe --unit kubelet

# Get the containerd status, logs and configuration
systemctl status containerd
journalctl -xe --unit containerd
containerd config dump
```

### AWS

Delete AMI:
1. Go to `EC2`, and then `AMIs`.
1. Right click on the AMI and select `Deregister AMI`
1. Remember the linked Snapshot ID shown when deregistering, and go `Snapshots`.
1. Right click on the Snapshot and select `Delect snapshot`


### Common cluster commands

Here is a series of frequent commands used during the cluster development

```bash
# Cluster creation
eksctl create cluster -f config/leaderboard-cluster.yaml --install-nvidia-plugin=false

# Nvidia Device Plugin
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.14.0/nvidia-device-plugin.yml

# Cluster autoscaler
kubectl apply -f config/cluster-autoscaler-autodiscover.yaml

# Fluentd
kubectl apply -f config/fluentd.yaml
kubectl apply -f jobs/carla-benchmark-job.yaml

# Cluster deletion
kubectl delete -f config/fluentd.yaml
kubectl delete -f jobs/carla-benchmark-job.yaml
eksctl delete cluster --region=us-west-2 --name=beta-leaderboard-20
```
