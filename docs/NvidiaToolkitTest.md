# Download nvidia-container-toolkit

```bash
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/libnvidia-container/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | sudo tee /etc/apt/sources.list.d/libnvidia-container.list

sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
```

# Run the AlphaDrive infraestructure AMI configuration

```bash
sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -q -y make gcc xserver-xorg mesa-utils libvulkan1 pkg-config nvidia-docker2 && sudo rm -rf /var/lib/apt/lists/*

# Install Nvidia drivers
NVIDIA_DRIVERS_VERSION="525.89.03"
wget http://download.nvidia.com/XFree86/Linux-x86_64/${NVIDIA_DRIVERS_VERSION}/NVIDIA-Linux-x86_64-${NVIDIA_DRIVERS_VERSION}.run
sudo /bin/bash NVIDIA-Linux-x86_64-${NVIDIA_DRIVERS_VERSION}.run --accept-license --no-questions --ui=none
rm NVIDIA-Linux-x86_64-${NVIDIA_DRIVERS_VERSION}.run

# Configure Docker
sudo sh -c "cat /etc/docker/daemon.json | jq '. += {\"default-runtime\": \"nvidia\", \"runtimes\": {\"nvidia\": {\"path\": \"/usr/bin/nvidia-container-runtime\", \"runtimeArgs\": []}}}' | tee /etc/docker/daemon.json"

# Restart Docker Service
sudo systemctl restart docker
```

# Permission denied from docker

```bash
sudo groupadd docker
sudo usermod -aG docker ${USER}
# Exit the reenter the instance
```