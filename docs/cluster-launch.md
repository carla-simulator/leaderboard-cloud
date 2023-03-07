```bash
# Create the cluster
eksctl create cluster -f challenge-cluster.yaml --install-nvidia-plugin=false

# In case of failure, delete it with 
eksctl delete cluster --region=us-east-2 --name=beta-leaderboard-20

# Install the NVIDIA Device plugin
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.13.0/nvidia-device-plugin.yml

# Download the autoscaler yaml
curl -O https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml

# (Change the image inside the yaml command by our own)

# Run the autoscaler
kubectl apply -f cluster-autoscaler-autodiscover.yaml

# Run a test job to test the autoscaler
kubectl apply -f tests/test-gpu-job.yaml