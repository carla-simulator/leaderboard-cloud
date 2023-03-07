# Get the logs of the autoscaler
kubectl -n kube-system logs -f deployment.apps/cluster-autoscaler

# Get the pods and nodes of the cluster
kubectl get nodes.pods -o wide

# Get the pods details
kubectl describe pod <pod-name>

# Delete
kubectl delete -f <yaml>
