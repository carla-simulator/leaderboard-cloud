# 1) Create the base AMI

Go to the supported AWS base images and select the latest kubernetes version (currently 1.24), the desired region and the *amd* architecture. In this case, the resulting AMI ID is `ami-0e11bb2963634f7a8`, but it will vary rapidly.

Click on the image and then launch it with `Launch instance from AMI`, at the top right corner. Do the follow configuration:
- Decide an instance name (i.e *carla-leaderboard-20-base-ami*)
- Choose the `g4dn.xlarge` type.
- Get a key pair login, which will be used to access the instance
- Get the Network setting (*launch-wizard-4*)

# 2) Prepare the base AMI

Enter through ssh:

```
ssh <key-file> -i ubuntu@<public-ip>
```

Download the dependencies
```bash
sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -q -y make gcc xserver-xorg mesa-utils libvulkan1 pkg-config && sudo rm -rf /var/lib/apt/lists/*
```

Download the NVIDIA drivers

```bash
NVIDIA_DRIVERS_VERSION="525.89.02"
wget http://download.nvidia.com/XFree86/Linux-x86_64/${NVIDIA_DRIVERS_VERSION}/NVIDIA-Linux-x86_64-${NVIDIA_DRIVERS_VERSION}.run
sudo /bin/bash NVIDIA-Linux-x86_64-${NVIDIA_DRIVERS_VERSION}.run --accept-license --no-questions --ui=none
rm NVIDIA-Linux-x86_64-${NVIDIA_DRIVERS_VERSION}.run
```

Use `nvidia-smi` to check that they have been correctly installed

Next, install the nvidia-container-toolkit with the following instructions

```bash
# Download some files
distribution=$(. /etc/os-release;echo $ID$VERSION_ID) \
   && curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add - \
   && curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list

# Install the NVIDIA container toolkit
sudo apt-get update && sudo apt-get install -y nvidia-container-runtime
```

Change the containerd configuration to use nvidia-container-toolkit
```bash
version = 2
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
            BinaryName = "/usr/bin/nvidia-container-runtime"
```

And restart *containerd*
```
sudo systemctl restart containerd
```

# 3) Save the AMI as a template

With the configuration done, it is now time to save the image as a template, so that all the workers don't need to repeat all these steps on initialization.

To do so, go to *Instances*, right click on the instance, then `Image and templates` and `Create image`. Use the follow naming convention when creating the instance:

`ubuntu-eks/k8s_${KUBERNETES_VERSION}/ubuntu-${UBUNTU_VERSION}/nvidia-${NVIDIA_DRIVERS_VERSION}/gpu-capabilities-enabled`

After several minutes, the instance will be created and the base AMI that we just created can be stopped / terminated.