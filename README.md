# leaderboard-cloud

This are the docs of the creation of the Leaderboard cloud using EvalAI, by and for people who have no knowledge of kubernetes. Most of the command lines will be tkaen from the [alphadrive-infraestructure](https://github.com/carla-simulator/alphadrive-infrastructure) repository. In a sense, this is an extension of that repo but explaining all the little things.

# Installation of *kubectl* and *eksctl*

- [**kubectl**](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/) and [**eksctl**](https://github.com/weaveworks/eksctl#installation)


# Creation of the cluster

## Create the base AMI

In order to set up the cluster, we need to define a base image that all the worker instances will use. In our case, the base image provided by AWS aren't useful, so we will have to create our own based on one of the available ones.

### Select a base image

In order to do that, decide on the base public image that closest fits our needs. The list of available ones is [here](https://cloud-images.ubuntu.com/docs/aws/eks/) and three things are important:

- **region**: choose an image based on the region where the cluster will be running
- **kubernetes version**: not all version are supported by AWS, so choose one from the list. It is recommended to choose the latest one, and make sure that it is the same as the kubernete's version at the cluster.
- **architecture**: make sure the architecture is *amd*, and not *arm*.

Once those are selected, save the AMI ID for the next step.

### Create the desired base AMI

With the base image decided, we can now create our desired AMI. To do so:

#### Launch an instance with the base image:

- Go to EC2 and then `Launch instance`.
- Use the previously gotten AMI ID as the base image for the instance
- Select the desired machine, which should be fine with a *g4dn.xlarge*.
- Create a new pair key, or use an existing one. These are your credentials and DO NOT LOSE the private key as it is not stored anywhere!
- Decide on the amount of storage (around 200 is good)
- Launch the instance

#### Configure the machine

With the instance ready, enter the machine and configure it for our purposes

Go to the instance in AWS, and get the public access key.


(((((((( Insert key image ))))))))

Enter the machine with ssh

```bash
ssh -i <path/key-pair-name.pem> ubuntu@<public-acces-key>
```

(((((((( Insert public access key ))))))))

Add the desired dependencies

```bash
# Install required Nvidia sources
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$(. /etc/os-release;echo $ID$VERSION_ID)/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list

# Dependencies
sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -q -y make gcc xserver-xorg mesa-utils libvulkan1 pkg-config nvidia-docker2 && sudo rm -rf /var/lib/apt/lists/*

# Install Nvidia drivers
NVIDIA_DRIVERS_VERSION="460.56"
wget http://download.nvidia.com/XFree86/Linux-x86_64/${NVIDIA_DRIVERS_VERSION}/NVIDIA-Linux-x86_64-${NVIDIA_DRIVERS_VERSION}.run
sudo /bin/bash NVIDIA-Linux-x86_64-${NVIDIA_DRIVERS_VERSION}.run --accept-license --no-questions --ui=none
rm NVIDIA-Linux-x86_64-${NVIDIA_DRIVERS_VERSION}.run

# Configure Docker
sudo sh -c "cat /etc/docker/daemon.json | jq '. += {\"default-runtime\": \"nvidia\", \"runtimes\": {\"nvidia\": {\"path\": \"/usr/bin/nvidia-container-runtime\", \"runtimeArgs\": []}}}' | tee /etc/docker/daemon.json"

# Restart Docker Service

sudo systemctl restart docker
```

#### Create the template

(Do something)


When using this command:

```bash
ubuntu-eks/k8s_${KUBERNETES_VERSION}/ubuntu-${UBUNTU_VERSION}/nvidia-${NVIDIA_DRIVERS_VERSION}/gpu-capabilities-enabled
```

- **kubernetes_version**: 1.24
- **ubuntu_version**: 20.04
- **NVIDIA_drivers_version**: (the most recent ones)





### Cluster yaml explanation

When creation the cluster, [alphadrive-cluster.yaml](https://github.com/carla-simulator/alphadrive-infrastructure/blob/main/eks/alphadrive-cluster.yaml) will be used. Here are the meaning of the different configurations:


- **metadata/name** is the name of the cluster
- **metadata/region** is the AWS region of the cluster
- **metadata/version** is the kubernetes version used. Make sure that the version is compatible with AWS

- **nodeGroups**: As the autoscaler is responsible of creating the nodes themselves, these node groups aren't the node themselves, but templates to be used when creating new instances. These are saved under *EC2/Launch templates*. Some of the parameters are:
    - **name**: name of the node
    - **amiFamily**:
    - **instanceType**: the AWS instance type to be used
    - **desiredCapacity**, **minSize**, **maxSize**: the limitations adn desired state of the autoscaler for this type of node
    - **labels**: used to identify the node by other parts of the cluster, such as services.
    - **ssh**: Indicates a specific ssh key to allow connection to the nodes through it. Some public keys can be used, or to create a new one, go to *Key Management Service* in AWS. [More info](https://eksctl.io/introduction/#ssh-access)
    - **iam/withAddonPolicies**: additional [policies](https://eksctl.io/usage/iam-policies/) can be added to the node. In this case, three policies will be added, the autoscaler, the [EBS](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html) and the [EFS](https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html)


### kube2iam

```
NODEGROUP_ROLES=$(
  aws iam list-instance-profiles | 
  jq -r '.InstanceProfiles[].InstanceProfileName' |
  grep eksctl-alphadrive-nodegroup |
  while read prof_name ; do
     aws iam get-instance-profile --instance-profile-name $prof_name | jq -r '.InstanceProfile.Roles[] | .RoleName'
  done
)
```

```
eksctl-alphadrive-nodegroup-basic-NodeInstanceRole-X019JEIFWG2T eksctl-alphadrive-nodegroup-gpu-NodeInstanceRole-1GF9K7650D22I
```

## Running CARLA on the instance

```bash
# 1) Install X server stuff (No idea what this does, and it doesn't seem to be needed for a local instance test)
sudo apt-get update
sudo apt-get install x11-xserver-utils
sudo apt-get install xdg-user-dirs
sudo apt-get install xdg-utils

grep --quiet tsc /sys/devices/system/clocksource/clocksource0/available_clocksource && sudo bash -c 'echo tsc > /sys/devices/system/clocksource/clocksource0/current_clocksource'
sudo nvidia-xconfig --preserve-busid -a --virtual=1280x1024
sudo X :0 -screen Screen0

# 2) Login to AWS
mkdir .aws
cat > .aws/credentials << EOF
[default]
aws_access_key_id = xxx
aws_secret_access_key = xxx
EOF
sudo $(aws ecr get-login --no-include-email --region us-east-1)

# 3) Download the dockers
sudo docker pull 342236305043.dkr.ecr.us-east-1.amazonaws.com/leaderboard-20-simulator
sudo docker pull 342236305043.dkr.ecr.us-east-1.amazonaws.com/leaderboard-20

# 4) Copy the LB and SR parts out of the dockers

sudo docker run -it --rm --volume=/tmp:/tmp:rw 342236305043.dkr.ecr.us-east-1.amazonaws.com/leaderboard-20 /bin/bash
sudo docker ps
export CONTAINER_ID=<container-id>
sudo docker cp $CONTAINER_ID:/workspace/scenario_runner/ /tmp/scenario-runner-master/
sudo docker cp $CONTAINER_ID:/workspace/leaderboard/ /tmp/leaderboard-master/
sudo docker cp $CONTAINER_ID:/workspace/CARLA/ /tmp/carla-root-master/

# 5) Run CARLA
export DISPLAY=0.1
sudo docker run -it --rm --net=host --runtime=nvidia \
#   -e SDL_VIDEODRIVER=x11 \
 -e DISPLAY=$DISPLAY \
 -e XAUTHORITY=$XAUTHORITY \
 -v /tmp/.X11-unix:/tmp/.X11-unix \
 -v $XAUTHORITY:$XAUTHORITY \
 --gpus=all \
 342236305043.dkr.ecr.us-east-1.amazonaws.com/leaderboard-20-simulator ./CarlaUE4.sh --vulkan -RenderOffScreen

# 6) Download and run the agent (using a LB 2.0 submitted agent as the test)
export AGENT_IMAGE=342236305043.dkr.ecr.us-east-1.amazonaws.com/bm-365c2ae6-team-1:1304109c-3e24-4470-a5d3-f2650acd28b0
sudo docker pull $AGENT_IMAGE

sudo docker run -it --rm --net=host --runtime=nvidia --gpus all \
    --volume=/tmp/scenario-runner-master/:/workspace/scenario_runner/:rw \
    --volume=/tmp/leaderboard-master/:/workspace/leaderboard/:rw \
    --volume=/tmp/carla-root-master/:/workspace/CARLA/:rw $AGENT_IMAGE /bin/bash
```

