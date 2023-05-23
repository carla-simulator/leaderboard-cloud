# Creation of the custom base AMI

As previously mentioned, let's start with the very core of the infraestructure, which is what's called as the base AMI. When starting any server, a base configuration has to be chosen, such as the type of architecture, operating system, installed software... AWS provides some basic ones, which users can modify to accomodate their needs, and then save as template. This removes the need to configure the machine everytime it is started (in this case, every time a submission starts).

### Select a base AMI

First of all, let's grab one of the official public AMIs from AWS. Go to the [Ubuntu on AWS EKS](https://cloud-images.ubuntu.com/docs/aws/eks/) website and select the image that best fits your needs. Decided on which one depending on these three criteria:

- **Kubernetes version**: Up to the user. These docs use *1.24*
- **AWS region**: Up to the user. These docs use *us-west-2*
- **architecture**: *amd*

Note that these two will affect the [cluster configuration](leaderboard_1.0/config/leaderboard-cluster.yaml), more on that in the [next section](leaderboard_1.0/docs/3_creation_of_the_cluster.md)

### Start a new EC2 machine

After selecting the desired AMI, click the `Launch instances from AMI` button, located on the top right corner. This will start the process to launch a machine using this AMI. Here are the recommended parameters:

- **Name and Tags**: As this instance is only temporary, the given isn't really important
- **Application and OS Images**: This should be already filled with the previously selected base AMI
- **Instance type**: Choose `g4dn.xlarge`. This doesn't define the cluster's GPU type, so a `g4dn.xlarge` is only used to check that the instance is correctly configured.
- **Key Pair**: Used to connect to the instance. Either choose or create a new one.
- **Network Settings**: Make sure the chosen one allows to SSH into the machine.
- **Configure storage**: 20GB should be enough. Again, this doesn't affect the cluster's storage, and it is only for testing purposes.

Launch to instance once everything is decided.

### Configure the machine

With the instance ready, let's configure it with the desired software. Go to the instance in AWS EC2 (you should already be there after launching the instance), get the public IP of the instance and SSH into the machine

```bash
ssh -i <private-key-file> ubuntu@<public-ip>
```

> Note: If the command fails due to the file's permissions being too open, change the `<private-key-file>` permissions by running `chmod 400 <private-key-file>`

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
NVIDIA_DRIVERS_VERSION="470.182.03"  # IMPORTANT: This are the recommended drivers to use.
wget http://download.nvidia.com/XFree86/Linux-x86_64/${NVIDIA_DRIVERS_VERSION}/NVIDIA-Linux-x86_64-${NVIDIA_DRIVERS_VERSION}.run
sudo /bin/bash NVIDIA-Linux-x86_64-${NVIDIA_DRIVERS_VERSION}.run --accept-license --no-questions --ui=none
rm NVIDIA-Linux-x86_64-${NVIDIA_DRIVERS_VERSION}.run

# Configure containerd to use NVIDIA Container Runtime
sudo bash -c "echo 'version = 2
[plugins]
  [plugins.\"io.containerd.grpc.v1.cri\"]
    [plugins.\"io.containerd.grpc.v1.cri\".containerd]
      default_runtime_name = \"nvidia\"

      [plugins.\"io.containerd.grpc.v1.cri\".containerd.runtimes]
        [plugins.\"io.containerd.grpc.v1.cri\".containerd.runtimes.nvidia]
          privileged_without_host_devices = false
          runtime_engine = \"\"
          runtime_root = \"\"
          runtime_type = \"io.containerd.runc.v2\"
          [plugins.\"io.containerd.grpc.v1.cri\".containerd.runtimes.nvidia.options]
            BinaryName = \"/usr/bin/nvidia-container-runtime\"' \
> /etc/containerd/config.toml"

# Restart containerd
sudo systemctl restart containerd
```

These commands install the dependencies as well as NVIDIA Container Runtime and NVIDIA Drivers, which are used to allow the instance to detect which GPUs are available. Containerd is also configured to use NVIDIA Container Runtime as its default runtime engine.

And important note about the NVIDIA Drivers used is that while it is generally recommended to use the most recent ones (`525.89.02` at the time) these were causing issues with the CARLA version used by the Leaderboard 2.0, and downgrading to `470.182.03` allowed it to be used for both Leaderboard 1.0 and 2.0 versions.

Check that the NVIDIA drivers have been correctly installed by running
```
nvidia-smi
```

and the NVIDIA Container Runtime
```
nvidia-container-cli -V
```

### Creating a new AMI

Exit the machine and go back to the EC2 dashboard. Select your instance and go to `Actions`, then `Images and 
templates` and `Create image`. The following naming convention is recommended:

* `ubuntu-eks/k8s_${KUBERNETES_VERSION}/ubuntu-${UBUNTU_VERSION}/nvidia-${NVIDIA_DRIVERS_VERSION}/gpu-capabilities-enabled`

Completing this guide would result, as an example, in the following name:

* `ubuntu-eks/k8s_1.24/ubuntu-20.04/nvidia-470.182.03/gpu-capabilities-enabled`

Now click on `Create` and, once it is ready, stop / terminate the EC2 image to prevent it from using resources.

### Check the AMI

The AMI should now be available in the EC2 dashboard, listed inside the AMIs section. Take note of the `AMI ID`, which will be used by the cluster configuration