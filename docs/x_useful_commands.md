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