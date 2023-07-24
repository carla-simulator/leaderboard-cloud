# Creation of the custom AMI

Before creating the configuration file, the AMI has to be created beforehand. This is then referenced by id, and `eksctl` will automatically get it from AWS EC2.

All instances part of a server have an AMI associated to them, which defines the type of architecture used, operating system, installed software... The AMI is used as a way to preconfigure the machine once, installing all the needed prerequisites, and then running it everytime a new machine is started, removing the need to configure all machine son initialization.

AWS provides some base ones, which users can modify to accomodate their needs, and then save as template.

### Select an existing base AMI

First of all, let's grab one of the official public AMIs from AWS. Go to the [Ubuntu on AWS EKS](https://cloud-images.ubuntu.com/docs/aws/eks/) website and select the image that best fits your needs. It should be decided based on these three criteria:

- **Kubernetes version**: Up to the user. These docs use *1.24*.
- **AWS region**: Up to the user. These docs use *us-west-2*.
- **architecture**: *amd*

### Configure the base AMI

After selecting the desired base AMI, click the `Launch instances from AMI` button, located on the top right corner. This will start the process to launch a machine using this AMI. Here are the recommended parameters:

- **Name and Tags**: Not really important, as this instance is only temporary.
- **Application and OS Images**: Already filled with the previously selected base AMI.
- **Instance type**: The only requirement is that the instance type has GPUs for a quick test. You can choose `g4dn.xlarge`.
- **Key Pair**: Used to connect to the instance. Either choose or create a new one.
- **Network Settings**: Make sure the chosen one allows to SSH into the machine.
- **Configure storage**: 20GB should be enough for testing purposes.

Launch the instance once everything is decided and wait for it to be ready. When the instance state changes to Running, get its `Public IPv4 Adress` from the Details below and SSH into the machine with

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

An important note about the NVIDIA Drivers used is that while it is generally recommended to use the most recent ones (`525.89.02` at the time og this docs) these were causing issues with CARLA's server so downgrading to `470.182.03` was needed.

Check that everything has been correctly installed by running
```bash
# NVIDIA drivers
nvidia-smi

# NVIDIA Container Runtime
nvidia-container-cli -V
```

### Creating a new AMI

Exit the machine and go back to the Instances section in AWS EC2. Select your instance and go to `Actions`, then `Images and 
templates` and `Create image`. The following naming convention is recommended:

* `ubuntu-eks/k8s_${KUBERNETES_VERSION}/ubuntu-${UBUNTU_VERSION}/nvidia-${NVIDIA_DRIVERS_VERSION}/gpu-capabilities-enabled`

Following the same versions as this docs would result in the following name:

* `ubuntu-eks/k8s_1.24/ubuntu-20.04/nvidia-470.182.03/gpu-capabilities-enabled`

Now click on `Create` and, once it is ready, the EC2 image can be stopped to prevent it from using resources. This instance won't be used again, so feel free to also terminate it if you want.

### Get the custom AMI ID

The AMI should now be available in the `AMI` section. Take note of the `AMI ID`, which will be used by the cluster configuration file.
