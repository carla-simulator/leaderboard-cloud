# Manage cluster access

By default, only the user that creates the cluster has access to it, which can be inconvenient in many use-cases, specially when actively developing a new infrastructure or debugging any issues. This section provides a way to allow others users access to the cluster. However, this access isn't fully complete, as the cluster deletion is still only available to the cluster's owner, and this access isn't reflected in the AWS interface, only through the `kubectl` commands.

### Create the IAM Role with admin access

Going back to the [cluster configuration file](docs/3_2_cluster_configuration.md) section, take note of the `iamIdentityMappings` that was created for the role with ARN `arn:aws:iam::342236305043:role/LB2-eks-admin`, granting it admin access.
```yaml
iamIdentityMappings:
  - arn: arn:aws:iam::342236305043:role/LB2-eks-admin
    groups:
      - system:masters
    username: admin
    noDuplicateARNs: true # prevents shadowing of ARNs
```

It is now time to create that IAM role and assign it to the interested users. First of all, create a policy called `LB2-eks-admin` with the following permissions in JSON format:
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

Next, create the IAM Role with the same name, `LB2-eks-admin`, and attached the policy to it. Lastly, either attach the policy to the users that want to have access to the cluster, or create a User Group and attach the policy to it. The second approach is generally the recommended one.

### Configure AWS CLI and kubectl

To access the cluster from kubectl, start by configuring AWS si that it uses the correct credentials to access the cluster. Add a new AWS profile by adding the following to the `~/.aws/config`
```bash
[profile eks-admin]
role_arn=arn:aws:iam::342236305043:role/LB2-eks-admin
source_profile=default                                  # This calls the 'default' .aws/credentials 
```

This creates a new profile called `eks-admin` with the previously created `LB2-eks-admin` role assigned to it, and the same default credentials.

Now, update the kubectl configuration with the cluster's information:
```bash
# Link kubectl with the Leaderboard 1.0 cluster
aws eks update-kubeconfig --region us-west-2 --name leaderboard-10 --alias l1

# Link kubectl with the Leaderboard 2.0 cluster
aws eks update-kubeconfig --region us-west-2 --name leaderboard-20 --alias l2
```

With that, navigate to `~/.kube/config`, where you can see all the clusters, contexts and users available. The last step is to specify that these clusters will be using the `eks-admin` profile, instead of the default one, so manually add them to the each of the users. It should result in something like this:
```yaml
- name: arn:aws:eks:us-west-2:342236305043:cluster/leaderboard-10
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1beta1
      args:
      - --region
      - us-west-2
      - eks
      - get-token
      - --cluster-name
      - leaderboard-10
      - --profile                         # Add these two lines
      - eks-admin                       # onto each user
      command: aws
```

Switch to the cluster by using the command
```bash
# Switch to the Leaderboard 1.0 cluster
kubectl config use-context l1

# Switch to the Leaderboard 2.0 cluster
kubectl config use-context l2
```

_NOTE: If this process has to be repeated once again due to, for example, the deletion of the cluster during testing, repeat these instructions skipping the creation of the `eks-admin` profile.

### Test the user access

Make sure that the process has been succesfully done by trying to get access to any of the cluster's data. Some examples of commands to run are

```bash
kubectl get nodes
kubectl describe node <NODE-NAME>
kubectl logs -n <NAMESPACE> <POD-NAME>
```
