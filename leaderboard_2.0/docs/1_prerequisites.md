# Prerequisites

Before starting with the infraestructure itself, let's take a look at what tools will be used to create it, which are mainly three.

### AWS CLI

In order to run the cloud infraestructure, the AWS services will be used. As such, users are expected to already have an AWS account available for them to use. 

Additionally, it is also recommended to install and configure the AWS CLI to target the desired account. Run the following commands to install AWS CLI:

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

> _More information available [here](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html#cliv2-linux-install)_

After the installation, configure AWS CLI to point to your account 

```
aws configure
```

This will prompt you to add your account information through the terminal. You should see something like:

```
AWS Access Key ID [None]: xxxxxxxx
AWS Secret Access Key [None]: xxxxxxxxxxxxxxxx
Default region name [None]: us-west-2
Default output format [None]: json
```

> _More information available [here](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html
)_

Check that the AWS CLI has been properly installed by checking its version with:
```
aws --version
```

### kubectl 

The next tool that will be used is Kubernetes, which will greatly smooth the creation of the cluster the CARLA Leaderboard runs in. To use it, install kubectl, which is the CLI tool used to interact with the Kubernetes cluster.

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

> _More information available [here](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)_

Check the kubectl version with:
```
kubectl version --client --output=yaml
```

### eksctl

Lastly, AWS EKS will be used, which is the official tool provided by AWS to manage Kubernetes clusters inside the users' account. And as expected, AWS EKS has its own CLI, which can be install with

```bash
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
```

> _More information available [here](https://github.com/weaveworks/eksctl)_

Check the eksctl version with:
```
eksctl version
```

### Docs versions

For full disclosure and to avoid possible changes in any of these three tools, here are the versions that were used when creating these docs:

- **AWS CLI**: 2.10.3
- **eksctl**: 0.145.0
- **kubectl**: 1.26
