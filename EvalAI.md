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

These are the preboot commands, which do something unknown

```bash
grep --quiet tsc /sys/devices/system/clocksource/clocksource0/available_clocksource && sudo bash -c 'echo tsc > /sys/devices/system/clocksource/clocksource0/current_clocksource'
# sudo sh -c "cat /etc/docker/daemon.json | jq '. += {\"default-runtime\": \"nvidia\", \"runtimes\": {\"nvidia\": {\"path\": \"/usr/bin/nvidia-container-runtime\", \"runtimeArgs\": []}}}' | tee /etc/docker/daemon.json"        This doesn't seem to be needed as it's already part of the base image?
sudo nvidia-xconfig --preserve-busid -a --virtual=1280x1024
sudo X :0&
```

From there, download the containers for the Leaderboard 2.0:

```bash
# Create the credentials file

# [default]
# aws_access_key_id = ???
# aws_secret_access_key = ???

# Login to AWS
sudo $(aws ecr get-login --no-include-email --region us-east-1)

docker pull 342236305043.dkr.ecr.us-east-1.amazonaws.com/leaderboard-20-simulator
docker pull 342236305043.dkr.ecr.us-east-1.amazonaws.com/leaderboard-20
```

Copy the LB and SR parts out of the dockers

```bash
docker run -it --rm --volume=/tmp:/tmp:rw 342236305043.dkr.ecr.us-east-1.amazonaws.com/leaderboard-20 /bin/bash
docker ps
export $CONTAINER_CP=
docker cp $CONTAINER_ID:/workspace/scenario_runner/ /tmp/scenario-runner-master/
docker cp $CONTAINER_ID:/workspace/leaderboard/ /tmp/leaderboard-master/
docker cp $CONTAINER_ID:/workspace/CARLA/ /tmp/carla-root-master/
```

<!--
Alphadrive also mounts this docker, but not sure what it does
```bash
- name: init-myservice
  image: busybox:1.28
  command: ['sh', '-c', 'mkdir -m 0777 -p /tmp/efs/$$carla_log_subpath$$ ; mkdir -m 0777 -p /tmp/efs/$$agent_log_subpath$$']
  volumeMounts:
    - mountPath: /tmp/efs
      name: efs-shared
``` -->

Run the CARLA docker:
- Problem 1: `error: XDG_RUNTIME_DIR not set in the environment.`. Added SDL_VIDEODRIVER, DISPLAY, XAUTHORITY envs and the two shared volumes
- Problem 2: `sh: 1: xdg-user-dir: not found`. 


```bash
sudo apt-get install x11-xserver-utils xdg-user-dirs xdg-utils # Install xhost
export DISPLAY=0

xhost local:root
docker run -it --rm \
  -e SDL_VIDEODRIVER=x11 \
  -e DISPLAY=$DISPLAY \
  -e XAUTHORITY=$XAUTHORITY \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v $XAUTHORITY:$XAUTHORITY \
  --gpus=all \
 342236305043.dkr.ecr.us-east-1.amazonaws.com/leaderboard-20-simulator ./CarlaUE4.sh
```

Download a random agent

```
echo $AGENT_IMAGE=342236305043.dkr.ecr.us-east-1.amazonaws.com/bm-365c2ae6-team-1:1304109c-3e24-4470-a5d3-f2650acd28b0
docker pull $AGENT_IMAGE
```


```bash
docker run -it --rm --net=host --runtime=nvidia --gpus all \
    --volume=/tmp/scenario-runner-master/:/workspace/scenario_runner/:rw \
    --volume=/tmp/leaderboard-master/:/workspace/leaderboard/:rw \
    --volume=/tmp/carla-root-master/:/workspace/CARLA/:rw $AGENT_IMAGE /bin/bash
```

