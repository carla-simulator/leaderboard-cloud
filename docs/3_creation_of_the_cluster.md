# Creation of the cluster

To create the cluster on Amazon Web Services you need to execute an `eksctl` command. This command expects one YAML which serves as the configuration file of the cluster. There is already one prepared [here](../config/leaderboard-cluster.yaml).

However, before executing it, modify the `nodeGroups[gpu].ami` to match the name of the AMI created on the previous section. Check the next section to understand how exactly does the file work

Once modified, execute the following command:

```bash
eksctl create cluster -f config/leaderboard-cluster.yaml --install-nvidia-plugin=false
```

> Take into account that the cluster creation can take up to 30 minutes. Go to `Cloudformation` in AWS for more details of the cluster status. This is also useful when deleting the cluster.

### Configuration of the YAML

Here are the most important sections of the configuration yaml.

First of all, we have to define the **name**, **AWS region** and **kubernetes version** of the cluster
```yaml
metadata:
  name: beta-leaderboard-20
  region: us-east-2
  version: "1.24"
```

Then, the IAM policies have to be described. This details all the exact permissions that each node has. For our case, three policies will be created. EXPLAIN POLICIES LATER
```yaml
iam:
  withOIDC: true
  serviceAccounts:
  - metadata:
      name: fluentd
      namespace: kube-system
    attachPolicy:
      Version: "2012-10-17"
      Statement:
      - Effect: Allow
        Action:
        - "logs:CreateLogStream"
        - "logs:CreateLogGroup"
        - "logs:PutLogEvents"
        - "logs:DescribeLogGroups"
        - "logs:DescribeLogStreams"
        Resource: "arn:aws:logs:*:*:*"
  - metadata:
      name: cluster-autoscaler
      namespace: kube-system
    wellKnownPolicies:
      autoScaler: true
  - metadata:
      name: submission-worker
    attachPolicy:
      Version: "2012-10-17"
      Statement:
      - Effect: Allow
        Action:
        # AWSAppRunnerServicePolicyForECRAccess
        - "ecr:GetDownloadUrlForLayer"
        - "ecr:BatchGetImage"
        - "ecr:DescribeImages"
        - "ecr:GetAuthorizationToken"
        - "ecr:BatchCheckLayerAvailability"
        # AWSS3FullAccess
        - "s3:*"
        - "s3-object-lambda:*"
        Resource:
        #- "arn:aws:s3:::"arn:aws:s3:::carla-leaderboard-20-logs"
        - "arn:aws:ecr:*:342236305043:repository/*"
```

Lastly, the `nodeGroups` section explains the nodes specifications. For our case, two types of nodes are used.

The first one is the `autoscaler-worker`, which is a one instance node responsible for running the autoscaler. As such, the `instanceType` and `volumeSize` have been chosen according to its needs.
```yaml
  - name: autoscaler-worker
    amiFamily: AmazonLinux2
    instanceType: t3.large
    desiredCapacity: 1
    volumeSize: 100
    labels:
      nodegroup-type: non-gpu
```

The second node, `submission-worker`, handles the evaluation of the user's submissions. With the use of the specified `tags`, we can tell the autoscaler to manage the amount of instances available of this type, which is determined by `desiredCapacity`, `minSize` and `maxSize`.

Optionally, to be able to access the instances through ssh, add the `ssh.publicKey` to the node configuration. Create the public key from the private one with the output of the command

```bash
ssh-keygen -y -f <private-key-file>
```

Additionally, the bootstrap commands offer the possibility to run specific commands on instance initialization. Regarding the `overrideBootstrapCommand`, the recommended commands to us are the first two commands. However, this removes the *containerd* configuration changes done when creating the base AMI, so they have to be remade again
```yaml
    overrideBootstrapCommand: |
      #!/bin/bash
      /etc/eks/bootstrap.sh beta-leaderboard-20
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
      sudo systemctl restart containerd
```

On the other hand, the `preBootstrapCommands` configure something about the X servers so that CARLA can run using Vulkan (we think)
```yaml
    preBootstrapCommands:
      - "grep --quiet tsc /sys/devices/system/clocksource/clocksource0/available_clocksource && sudo bash -c 'echo tsc > /sys/devices/system/clocksource/clocksource0/current_clocksource'"
      - "sudo nvidia-xconfig --preserve-busid -a --virtual=1280x1024"
      - "sudo X :0&"
```

Lastly, remember to change the `ami` id to the base AMI created in the previous section.

### NVIDIA Device Plugin

For the NVIDIA GPUs to be detected as available resources, a plugin needs to be installed. It is publicly available on the NVIDIA repositories. Make sure to install the latest version by checking the [Releases](https://github.com/NVIDIA/k8s-device-plugin/releases) section. In the case of this docs, 

```
kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.13.0/nvidia-device-plugin.yml
```

### Cluster Autoscaler

The next step is to add the autoscaler resources to the cluster. Download the [most recent version](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml) and change *<YOUR CLUSTER NAME>* near the end of the file with our own cluster name.

The one used by these docs is located [here](../config/cluster-autoscaler-autodiscover.yaml), which can then be applied to the cluster with the command
```bash
kubectl apply -f config/cluster-autoscaler-autodiscover.yaml
```

### Test the cluster

To ensure that all of the previous steps have been correctly apllied, here is a quick test to do, taken from [this section](https://github.com/NVIDIA/k8s-device-plugin#running-gpu-jobs) in the NVIDIA Device plugin.

Start the pod by running
```
kubectl apply -f tests/test-gpu-job.yaml
```

This will start a Job that requires a GPU, which should be detected by the autoscaler, creating a new instance automatically.

Monitor the amount of instances created at the cluster with
```
watch kubectl get nodes,pods -o wide
```

If everything works, you will see that while the cluster starts with only 1 node, a new one will be automatically created. After several minutes, the pod will be ready and the job completed. You can check that the job has succesfully run by getting its logs
```
kubectl logs gpu-pod
```

After that, delete the job
```
kubectl delete -f tests/test-gpu-job.yaml
```
and the autoscaler will automatically remove the previously created pod, as it is no longer necessary.

In case of failure, check the [useful commands](x_useful_commands.md) section to debug it.
