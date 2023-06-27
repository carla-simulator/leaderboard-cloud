# (Optional) Understading the configuration YAML

This section focuses on understanding the most important sections of the cluster's configuration.

The first two elements of the file are the *apiVersion* and the *kind*. Instead of passing an argument through `eksctl`, these two lines tell EKS what to expect from this file.
```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
```

This is followed by the `metadata`, which defines the name of the cluster, AWS region and Kubernetes version used. Remember that this has to match the values set by the base AMI.
```yaml
metadata:
  name: beta-leaderboard-20
  region: us-west-2
  version: "1.24"
```

The next step is related to AWS IAM, and will be used by EKS to allow access to other users apart from the creator of the cluster to modify it. In essence, this gives admin privileges to everyone, but only the creator can delete the cluster. Check for information [here](3_2_granting_cluster_access.md)
```yaml
iamIdentityMappings:
  - arn: arn:aws:iam::342236305043:role/LB2-eks-admin
    groups:
      - system:masters
    username: admin
    noDuplicateARNs: true # prevents shadowing of ARNs
```

Then, the IAM policies are described. Creating the policies during the cluster configurations allows EKS to attach specific AWS policies to ServiceAccounts, which will later be linked to the nodes that need these permissions. Three types of service accounts are created for the cluster:
- **fluentd**: Fluentd is a tool used to get the logs of the cluster and upload them to AWS Cloudwatch. As such, it needs access to create them. More information [here](4_logging_results_to_cloudwatch.md)
- **cluster-autoscaler**: Used to automatically scale the cluster to avoid wasting unneeded resources. The *autoScaler* well known policy can be used.
- **submission-worker**: The service account of the Leaderborad submission itself. Needs access to ECR to download the user's docker as well as S3 to upload the submission results.
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
        - "arn:aws:s3:::beta-leaderboard-20"
        - "arn:aws:s3:::beta-leaderboard-20/*"
        - "arn:aws:ecr:*:342236305043:repository/*"
```

Lastly, the `nodeGroups` section explains the nodes specifications. Two types of nodes are used, the `basic-worker`, which handles the autoscaler, and the `submission-worker`, which runs the CARLA server and Leaderboard.

For the autoscaler node, a `t3.large` instance type is more than enough, as it doesn't use a GPU, and is the only node that will be running all the time.
```yaml
  - name: basic-worker
    amiFamily: AmazonLinux2
    instanceType: t3.large
    desiredCapacity: 1
    volumeSize: 100
    labels:
      role: basic-worker
```

On the other hand, the submission worker has more configuration parameters. The chosen instance type is the `g5.12xlarge`, which has 4 GPUs and allows the submission to be parallelized in 4, speeding its computation time. Feel free to change the instance type to match the desired criteria, but make sure it is the same the as the ones used byt the [submission job](../jobs/carla-benchmark-job.yaml).

The `ami` parameter should match the one created [here](2_creation_of_the_base_ami.md), and the `desiredCapacity`, `minSize` and `maxSize`, along with the `tags` describe the autoscaler specifications. Note that the second tag has the cluster name, and might need to be modified.

Lastly, the `overrideBootstrapCommand` and `preBootstrapCommands` are a list of commands automatically applied each time a new instance is created. Note that the `overrideBootstrapCommand` reconfigures containerd to use the NVIDIA Container Runtime due to EKS reconfiguring it to the default values if left empty. It is unclear whether or not the `preBootstrapCommands` could be part of the base AMI or not, but this worked before, so it is staying like that.

```yaml
  - name: submission-worker
    instanceType: g5.12xlarge
    amiFamily: Ubuntu2004
    ami: ami-05c54e41645c675fe
    desiredCapacity: 0
    minSize: 0
    maxSize: 10
    volumeSize: 400
    tags:
      k8s.io/cluster-autoscaler/enabled: "true"
      k8s.io/cluster-autoscaler/beta-leaderboard-20: "owned"
    labels:
      role: submission-generic-worker
    ssh:
      publicKey: "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDkL6oBOlOqWp4BgOIsQnHQkaPCEGQjdqwWPy1WXLPEnjMLQ3iFGK+zMJ3VNhYujhemn2Yxja8Yw+a0MWv0OfV9TTcW6gsjsBuZyBA0g7OkaFFrAiEi42gajqqnBCEpbEL8/+MYnOHSYCqIXi7yyzHwDGuUzBsyTTsbAmdvuQ8o7sh7QH0Ncw5Z7605RTQI1MxP2zAQdl/UdZipFH9Q3pCidwWLJ3WFYTvKkhpEjiUyrf2sfPya89yFQdfLytpX4mW/YRsvLIoBElJYDkcAkyGPU6N0o+CoXyFg1ezvB9rXFsW1XgRf4ZR3nKxiM9yi1N1Z0/rf5hUWseNRt6/Xl0pn"
    overrideBootstrapCommand: |
      #!/bin/bash
      /etc/eks/bootstrap.sh beta-leaderboard-20
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
      sudo systemctl restart containerd
    preBootstrapCommands:
      - "sudo nvidia-xconfig --preserve-busid -a --virtual=1280x1024"
      - "sudo X :0&"
```

To get the publick key: `ssh-keygen -y -f carla-leaderboard-20.pem`
