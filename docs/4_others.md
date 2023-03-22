# Granting access to other users to the cluster

### 1

First of all, we have to create an IAM Role 

- IAM Role
- Create Role
- AWS Account and select *This Account* 
- No policies as we'll AssumeRole
- Don't modifiy the JSON descripotion of the role
For this case: named LB2-eks-admin

### 2

Create a new policy with this JSON
```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowAssumeOrganizationAccountRole",
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::342236305043:role/LB2-eks-admin"
    }
  ]
}
```
For this case: named LB2-eks-admin

### 3

Create a group named `LB2_CLOUD` with the `LB2-eks-admin` policy and add the desired users

### 4 

Change the cluster by adding the IAM IDentity Mappings

```yaml
iamIdentityMappings:
  - arn: arn:aws:iam::342236305043:role/LB2-eks-admin
    groups:
      - system:masters
    username: admin
    noDuplicateARNs: true # prevents shadowing of ARNs
```

### 5

For the users that didn't create the cluster, update the kube config to tell it to 'connect' to the cluster
```
aws eks update-kubeconfig --region us-east-2 --name beta-leaderboard-20  # More than just profile eks-admin
```

To avoid possible issues later on with the permissions of the AWS default profile, it is recommended to create and use a new profile. As such, go to `~/.aws/config` and add. 
```bash
[profile eks-admin]
role_arn=arn:aws:iam::342236305043:role/LB2-eks-admin
source_profile=default                                  # This calls the 'default' .aws/credentials 
```

This create a new profile called `eks-admin` with the previously created `LB2-eks-admin` role assigned to the profile, as well as giving it the default credentials.

Lastly, change the kubectl configuration to use the new profile. You can either manually add the profile to the `~/.kube/config` file like this
```yaml
users:
  - name: arn:aws:eks:us-east-2:342236305043:cluster/beta-leaderboard-20
    user:
      exec:
        apiVersion: client.authentication.k8s.io/v1beta1
        args:
          - --region
          - us-east-2
          - eks
          - get-token
          - --cluster-name
          - beta-leaderboard-20
          - --profile                       # This 
          - eks-admin                       # and this
        command: aws
```

or do it the easy but not very user-friendly way
```bash
sudo snap install yq
sudo apt install moreutils
export KUBECONFIG=~/.kube/config  # Default path of the kube config file
cat $KUBECONFIG | yq e '.users.[].user.exec.args += ["--profile", "eks-admin"]' - -- | sed 's/beta-leaderboard-20./beta-leaderboard-20-admin./g' | sponge $KUBECONFIG
```

Note: This doesn't grant full access to the cluster as the deletion of the cluster is still only doable by the creator, and the cluster is still unavailable through the AWS EKS interface.