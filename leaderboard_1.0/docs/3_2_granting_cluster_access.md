# Granting access to other users

By default, only the user that created the cluster has access to it, which can be inconvenient in some cases. This section provides a way to allow others users access to it. However, this is only half-way done as the cluster deletion is still only available to the cluster owner, and this access isn't applied to the AWS interface.

### Create the IAM credentials

First of all, an IAM Role has to be created. When creating it, set the `Trusted entity type` to `AWS Account` and choose *This account*. There is no need to add any policies to the role for now. Decide on a name for the role. From here on, all references to the role will suppose that its name is `LB2-eks-admin`.

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
Choose a name for the policy. For this docs, the policy name is `LB2-eks-admin`, which matches the role one.

Lastly, instead of attaching the policy to a users, it is recommended to create a new user group, such as `LB2_CLOUD`, add all the users that want access to the cluster to that group, and add the `LB2-eks-admin` policy to the user group.

### Modify the cluster configuration

Before starting the cluster, go to the `iamIdentityMappings` at the [cluster configuration yaml](../config/leaderboard-cluster.yaml) and modify the *arn* to match the one with previouslt created one.

```yaml
iamIdentityMappings:
  - arn: arn:aws:iam::342236305043:role/LB2-eks-admin
    groups:
      - system:masters
    username: admin
    noDuplicateARNs: true # prevents shadowing of ARNs
```

### Configure the other users

After the cluster is created, other users can now connect to it. First of all, update the EKS config with the name and region of the cluster, such as
```bash
aws eks update-kubeconfig --region us-west-2 --name beta-leaderboard-10
```
> Note: If the command fails with `'NoneType' object is not iterable`, remove the `~/.kube` folder.

Now, configure AWS to use the correct credentials to access the cluster. There are several ways to do so but the recommended one here is to create a new user profile to avoid modifying the *default* one. As such, go to `~/.aws/config` and add
```bash
[profile eks-admin]
role_arn=arn:aws:iam::342236305043:role/LB2-eks-admin
source_profile=default                                  # This calls the 'default' .aws/credentials 
```

This creates a new profile called `eks-admin` with the previously created `LB2-eks-admin` role assigned to the profile. The last line calls the *default* credentials at `~/.aws/credentials`, which should be the most common configuration, but this might depend on the user.

Lastly, the kubectl configuration has to be changed to use the new profile. This is done by adding the `eks-admin` profile to the `~/.kube/config` file. The following commands do this programatically (and in a non very user-friendly way):
```bash
sudo snap install yq
sudo apt install moreutils
cat ~/.kube/config | yq e '.users.[].user.exec.args += ["--profile", "eks-admin"]' - -- | sed 's/beta-leaderboard-10./beta-leaderboard-10-admin./g' | sponge ~/.kube/config
```

### Test the user access

Make sure that the process has been succesfully done by trying to get access to any of the cluster's data. Some examples are

```bash
kubectl get nodes
kubectl describe node <NODE-NAME>
kubectl logs -n <NAMESPACE> <POD-NAME>
```

### 2nd cluster and beyond

If this process has to be repeated once again due to, for example, the deletion of the cluster, this process is simplified to:
```bash
aws eks update-kubeconfig --region us-west-2 --name beta-leaderboard-10
cat ~/.kube/config | yq e '.users.[].user.exec.args += ["--profile", "eks-admin"]' - -- | sed 's/beta-leaderboard-10./beta-leaderboard-10-admin./g' | sponge ~/.kube/config
```

which tells EKS to connect to the cluster, and modify kubectl configuration with the already existing profile.
