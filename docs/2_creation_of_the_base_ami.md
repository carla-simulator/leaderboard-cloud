# Creation of the custom base AMI

Before creating the cluster, a base AMI will be created, which will be later used by all the user submissions's that arrive to the cluster. This will allow us to preconfigure the instance as desired, and by saving it as a template later, we will avoid having to do this step each time a new instance is started.

### Select a base AMI

While we will be using our own base AMI, it will be created on top of a public one. Go to the [Ubuntu on AWS EKS](https://cloud-images.ubuntu.com/docs/aws/eks/) website and select the image that best fits your needs. There are two criteria to take into account:

- **Kubernetes version**
- **AWS region**

Decide on these two based on the [cluster configuration](config/leaderboard-cluster.yaml)

### Start a new EC2 machine

Go to the AWS EC2 dashboard and, inside the Instances menú, click on `Launch instances`. On the following AMI menu, 
locate the AMI selected on the previous step and mark it as your selected configuration.

On the next step, you need to select an Instance Type that uses an Nvidia GPU. For this purpose, a `g4dn.xlarge` machine
is enough. 

Now, click on Review and Launch. Not check it and launch the image. Create a new key pair if you need to.

### Configure the machine

SSH into the machine to configure it. Go to the instance in AWS, get its public IP and enter it with

```bash
ssh <private-key-file> -i ubuntu@<public-ip>
```

> Note: If the command fails due to the file's permissions being too open, change then by running `chmod 400 <private-key-file>`

Once inside run the following commands:

```bash
# Install the dependencies
sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -q -y make gcc xserver-xorg mesa-utils libvulkan1 pkg-config && sudo rm -rf /var/lib/apt/lists/*

# Install NVIDIA Container Runtime
distribution=$(. /etc/os-release;echo $ID$VERSION_ID) \
   && curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add - \
   && curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list

sudo apt-get update && sudo apt-get install -y nvidia-container-runtime && sudo rm -rf /var/lib/apt/lists/*

# Install Nvidia Drivers
NVIDIA_DRIVERS_VERSION="525.89.02"  # IMPORTANT: It is recommended to always use the most recent one
wget http://download.nvidia.com/XFree86/Linux-x86_64/${NVIDIA_DRIVERS_VERSION}/NVIDIA-Linux-x86_64-${NVIDIA_DRIVERS_VERSION}.run
sudo /bin/bash NVIDIA-Linux-x86_64-${NVIDIA_DRIVERS_VERSION}.run --accept-license --no-questions --ui=none
rm NVIDIA-Linux-x86_64-${NVIDIA_DRIVERS_VERSION}.run

# Configure containerd to use NVIDIA Container Runtime
sudo echo 'version = 2
[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    [plugins."io.containerd.grpc.v1.cri".containerd]
      default_runtime_name = "nvidia"

      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia]
          privileged_without_host_devices = false
          runtime_engine = ""
          runtime_root = ""
          runtime_type = "io.containerd.runc.v2"
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia.options]
            BinaryName = "/usr/bin/nvidia-container-runtime"' \
> /etc/conatinerd/config.toml

# Restart containerd
sudo systemctl restart containerd
```

Check that the NVIDIA drivers have been correctly installed by running
```
nvidia-smi
```

and the NVIDIA Container Runtime
```
nvidia-container-cli -V
```

### Creating a new AMI

Escape from the machine and go back to the EC2 dashboard. Select your instance and click on `Actions` > `Images and 
templates` > `Create image`. Use the following naming convention:

* `ubuntu-eks/k8s_${KUBERNETES_VERSION}/ubuntu-${UBUNTU_VERSION}/nvidia-${NVIDIA_DRIVERS_VERSION}/gpu-capabilities-enabled`

Completing this guide would result, as an example, in the following name:

* `ubuntu-eks/k8s_1.24/ubuntu-20.04/nvidia-525.89.02/gpu-capabilities-enabled`

Now click on `Create` and, once it is ready, stop / terminate the EC2 image to prevent it from using resources.

### Check the AMI

The AMI should now be available in the EC2 dashboard, listed inside the AMIs section. Take note of the `AMI ID`, which will be used by the cluster configuration