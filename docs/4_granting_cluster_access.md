# Granting access to other users

In this section, we will explain how to make users othen than the cluster's owner have access to it. This is currently kind of half-way done as the cluster deletion is still only available to the cluster owner, and this access isn't applied to the AWS interface.

### Create the IAM credentials

First of all, we have to create an IAM Role. Go to the AWS interface and start to create a role. Set the `Trusted entity type` to `AWS Account` and choose *This account*. Don't add any policies, as we are only interested in the `sts:AssumeRole` Action. Decide on a name for the role. From here on, all references to the role will suppose that its name is `LB2-eks-admin`.

With the role created, create a policy with this JSON
```json
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
Choose a name for the policy. Here, the policy name matches the role one, being `LB2-eks-admin`.

Lastly, instead of attaching the policy to a users, it is recommended to create a new user group, such as `LB2_CLOUD`, add all the users that want access to the cluster to that group, and add the `LB2-eks-admin` policy to the user group

### Modify the cluster configuration

Before starting the cluster, add the following configuration to the [configuration yaml](../config/leaderboard-cluster.yaml), adding *iamIdentityMappings*. It is recommended to put it just before the *iam* section, but its position doesn't affect its result.

```yaml
iamIdentityMappings:
  - arn: arn:aws:iam::342236305043:role/LB2-eks-admin
    groups:
      - system:masters
    username: admin
    noDuplicateARNs: true # prevents shadowing of ARNs
```

You can now create the cluster

### Configure the other users

After the cluster is created, it is time to configure the users other than the cluster's owner. Start by telling AWS to connect to the cluster with
```
aws eks update-kubeconfig --region us-east-2 --name beta-leaderboard-20
```
> Note: If the command fails with `'NoneType' object is not iterable`, remove the `~/.kube` folder.

Now, we have to tell AWS to use the correct credentials to access the cluster. To avoid modifying the *default* user profile (which can rsult in future issues), it is recommended to create and use a new one. As such, go to `~/.aws/config` and add
```bash
[profile eks-admin]
role_arn=arn:aws:iam::342236305043:role/LB2-eks-admin
source_profile=default                                  # This calls the 'default' .aws/credentials 
```

This creates a new profile called `eks-admin` with the previously created `LB2-eks-admin` role assigned to the profile. The last line calls the *default* credentials at `~/.aws/credentials`, which should be the most common configuration, but change it your own if this isn't the case.

Lastly, change the kubectl configuration to use the new profile by adding the `eks-admin` profile to the `~/.kube/config` file. This can be done with the following (non very user-friendly) commands.
```bash
sudo snap install yq
sudo apt install moreutils
cat ~/.kube/config | yq e '.users.[].user.exec.args += ["--profile", "eks-admin"]' - -- | sed 's/beta-leaderboard-20./beta-leaderboard-20-admin./g' | sponge ~/.kube/config
```

### Test the user access

Make sure that the process has been succesfully done by trying to get access to any of the cluster's data. Some examples are

```bash
kubectl get nodes
kubectl describe node <NODE-NAME>
kubectl logs -n <NAMESPACE> <POD-NAME>
```

### 2nd cluster and beyond

In the case of the cluster deletion, this configuration will not automatically work for all the other subsequent clusters, even if their names are the same. to update to the new cluster
```bash
aws eks update-kubeconfig --region us-east-2 --name beta-leaderboard-20
cat ~/.kube/config | yq e '.users.[].user.exec.args += ["--profile", "eks-admin"]' - -- | sed 's/beta-leaderboard-20./beta-leaderboard-20-admin./g' | sponge ~/.kube/config
```