# Prerequisites

Let's start by downloading all the dependenciess needed.

### AWS CLI

AWS Command Line Interfaces is going to be assumed to be installed and properly configured, targeting the desired 
account.

Install the AWS CLI with the following commands

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

> _More information available [here](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html#cliv2-linux-install)_

After the installation, configure AWS with your account 

```
aws configure
```

This will prompt you to add your account information through the terminal. You should see something like:

```
AWS Access Key ID [None]: xxxxxxxx
AWS Secret Access Key [None]: xxxxxxxxxxxxxxxx
Default region name [None]: us-east-2
Default output format [None]: json
```

> _More information available [here](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html
)_

Check the AWS CLI version with:
```
aws --version
```

### eksctl

eksctl is a simple CLI tool for creating clusters on EKS. Install it with

```bash
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
```

> _More information available [here](https://github.com/weaveworks/eksctl)_


Check the eksctl version with:
```
eksctl version
```

### kubectl 

kubectl is a CLI tool used to interact with the Kubernetes cluster.

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

> _More information available [here](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)_

Check the kubectl version with:
```
kubectl version --client --output=yaml
```

### Docs versions

For full disclosure, the following versions were used when creating this docs:

- **AWS CLI**: aws-cli/2.10.3
- **eksctl**: 0.130.0
- **kubectl**: 1.26
