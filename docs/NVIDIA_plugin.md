# New NVIDIA device plugin docs

```bash
# Install helm
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm


# Set up the plugin's helm repo and update it
helm repo add nvdp https://nvidia.github.io/k8s-device-plugin
helm repo update

# Install it?
helm upgrade -i nvdp nvdp/nvidia-device-plugin \
  --namespace nvidia-device-plugin \
  --create-namespace

# Something ConfigMap
cat << EOF > /tmp/dp-example-config0.yaml
version: v1
flags:
  migStrategy: "none"
  failOnInitError: true
  nvidiaDriverRoot: "/"
  plugin:
    passDeviceSpecs: false
    deviceListStrategy: envvar
    deviceIDStrategy: uuid
EOF

helm upgrade -i nvdp nvdp/nvidia-device-plugin \
    --namespace nvidia-device-plugin \
    --create-namespace \
    --set-file config.map.config=/tmp/dp-example-config0.yaml

```
```bash
# Install required Nvidia sources
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$(. /etc/os-release;echo $ID$VERSION_ID)/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list

# Dependencies
sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -q -y make gcc xserver-xorg mesa-utils libvulkan1 pkg-config nvidia-docker2 && sudo rm -rf /var/lib/apt/lists/*

# Configure Docker
sudo sh -c "cat /etc/docker/daemon.json | jq '. += {\"default-runtime\": \"nvidia\", \"runtimes\": {\"nvidia\": {\"path\": \"/usr/bin/nvidia-container-runtime\", \"runtimeArgs\": []}}}' | tee /etc/docker/daemon.json"

# Restart Docker Service
sudo systemctl restart docker

```