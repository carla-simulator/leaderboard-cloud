```bash
# Create the cluster
eksctl create cluster -f challenge-cluster.yaml --install-nvidia-plugin=false

# In case of failure, delete it with 
eksctl delete cluster --region=us-east-2 --name=beta-leaderboard-20

# Download the autoscaler yaml
curl -O https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml

# Change the image inside the yaml command by our own
kubectl apply -f cluster-autoscaler-discovery.yaml

# Test the autoscaler
