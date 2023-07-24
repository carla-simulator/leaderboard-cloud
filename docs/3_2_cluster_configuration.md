# Creation of the configuration file

With the custom AMI ready, it is time to create the configuration files. These files are in the repository for both the [Leaderboard 1.0](/leaderboard_1.0/config/leaderboard-cluster.yaml) and [Leaderboard 2.0](/leaderboard_2.0/config/leaderboard-cluster.yaml). The example code below are snipets of the Leaderboard 1.0 configuration, but the only difference with the Leaderboard 2.0 are the hardcoded names of elements such as the cluster and database names.

## Starting elements

The first two elements of the file are the *apiVersion* and the *kind*. These two lines tell EKS what to expect from this file.
```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
```

This is followed by the `metadata`, which defines the name of the cluster, AWS region and Kubernetes version used. Remember that this has to match the values set by the custom AMI.
```yaml
metadata:
  name: leaderboard-10
  region: us-west-2
  version: "1.24"
```

# Node groups

Ignoring the iam sections for now, the `nodeGroups` detail the two types of nodes used by the cluster, the `basic-worker`, which handles the autoscaler, and the `submission-worker`, which runs either the CARLA server or the agent.

_NOTE: There is another type of node groups called `managedNodeGroups` which might also be used, but testing showed that the unmananged ones seemed better suited for the Leaderboard case.

For the autoscaler node, just note that it is a monitoring tool that doesn't use any GPU, so a `t3.large` instance type is a good choice, with a volume size of 100.
```yaml
  - name: basic-worker
    amiFamily: AmazonLinux2
    instanceType: t3.large
    desiredCapacity: 1
    volumeSize: 100
    labels:
      role: basic-worker
```

On the other hand, the submission worker has more configuration parameters. The chosen instance type this time is the `g5.12xlarge`, which has 4 GPUs. This allows the parallelization of the submision in 4 parts, speeding its computation time.

The `ami` parameter should match the `AMI ID` of the previously created [custom AMI](/docs/3_1_creation_of_the_ami.md), and the `desiredCapacity`, `minSize` and `maxSize`, along with the `tags` describe the autoscaler specifications.

_NOTE: The second tag has the cluster name as part of it, and might need to be modified by the user.

The ssh `publicKey` can be gotten from the key pair used when creating the custom AMI using: `ssh-keygen -y -f <key-name.pem>`

Lastly, the `overrideBootstrapCommand` and `preBootstrapCommands` are a list of commands automatically applied each time a new instance is created. Ideally, all of this should be part of the custom AMI, but previous iteration of the backend used this configuration, so this hasn't been changed.

Note that the `overrideBootstrapCommand` reconfigures containerd to use the NVIDIA Container Runtime, same as it was done in the custom AMI. This is because if left empty, EKS reconfigures it to the default values. It is unclear if this could be fixed.

```yaml
  - name: submission-worker
    instanceType: g5.12xlarge
    amiFamily: Ubuntu2004
    ami: ami-05c54e41645c675fe
    desiredCapacity: 0
    minSize: 0
    maxSize: 2
    volumeSize: 400
    tags:
      k8s.io/cluster-autoscaler/enabled: "true"
      k8s.io/cluster-autoscaler/leaderboard-10: "owned"
    labels:
      role: submission-generic-worker
    ssh:
      publicKey: "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDkL6oBOlOqWp4BgOIsQnHQkaPCEGQjdqwWPy1WXLPEnjMLQ3iFGK+zMJ3VNhYujhemn2Yxja8Yw+a0MWv0OfV9TTcW6gsjsBuZyBA0g7OkaFFrAiEi42gajqqnBCEpbEL8/+MYnOHSYCqIXi7yyzHwDGuUzBsyTTsbAmdvuQ8o7sh7QH0Ncw5Z7605RTQI1MxP2zAQdl/UdZipFH9Q3pCidwWLJ3WFYTvKkhpEjiUyrf2sfPya89yFQdfLytpX4mW/YRsvLIoBElJYDkcAkyGPU6N0o+CoXyFg1ezvB9rXFsW1XgRf4ZR3nKxiM9yi1N1Z0/rf5hUWseNRt6/Xl0pn"
    overrideBootstrapCommand: |
      #!/bin/bash
      /etc/eks/bootstrap.sh leaderboard-10
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

# IAM permissions

The configuration file also allows the creation of AWS IAM Roles at the `iam` section, which have their lifetime attached to the cluster, being created and deleted along with it. These roles are automatically attached to a [Kubernetes ServiceAccount](https://kubernetes.io/docs/concepts/security/service-accounts/) so that others can make easy use of the permissions these roles provide. Three ServiceAccounts are created in this file.

The first one will be attached to FluentD, which needs permission to add logs onto AWS Cloudwatch.
```yaml
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
```

The next is the autoscaler one, and it is such a common tool that the `wellKnownPolicies` can be used
```yaml
- metadata:
    name: cluster-autoscaler
    namespace: kube-system
  wellKnownPolicies:
    autoScaler: true
```

The third ServiceAccount is linked with the `submission-worker`, which performs several actions in AWS that need permissions such as downloading the containers from AWS ECR, uploading information onto AWS S3 and updating the DynamoDB database.
```yaml
  - metadata:
      name: submission-worker
    attachPolicy:
      Version: "2012-10-17"
      Statement:
      - Effect: Allow
        Action:
        # Based on AWSAppRunnerServicePolicyForECRAccess, grants acces to download the ECR docker images
        - "ecr:GetDownloadUrlForLayer"
        - "ecr:BatchGetImage"
        - "ecr:DescribeImages"
        - "ecr:GetAuthorizationToken"
        - "ecr:BatchCheckLayerAvailability"
        # Based on AWSS3FullAccess, grant read + write access to S3“
        - "s3:*"
        - "s3-object-lambda:*"
        # DynamoDB
        - "dynamodb:GetItem"
        - "dynamodb:DeleteItem"
        - "dynamodb:PutItem"
        - "dynamodb:UpdateItem"
        Resource:
        # All ECR repositories, a specific S3 bucket, and the database
        - "arn:aws:ecr:*:342236305043:repository/*"
        - "arn:aws:s3:::leaderboard-10*"
        - "arn:aws:dynamodb:*:342236305043:table/leaderboard-10"
```

On the other hand, the `iamIdentityMappings` provides specific roles with admin privileges. These roles are `LB2-eks-admin`, used to grant access to the cluster to users other than its creator, and the `LeaderboardStepFunctionRole`, the IAM Role created when setting up the Step Functions. These roles are permanent ones and will be created later on, so make sure their name is the same as the ones part of this configuration file.
```yaml
iamIdentityMappings:
  - arn: arn:aws:iam::342236305043:role/LB2-eks-admin
    groups:
      - system:masters
    username: admin
    noDuplicateARNs: true # prevents shadowing of ARNs
  - arn: arn:aws:iam::342236305043:role/LeaderboardStepFunctionRole
    groups:
      - system:masters
    username: admin
    noDuplicateARNs: true # prevents shadowing of ARNs
```