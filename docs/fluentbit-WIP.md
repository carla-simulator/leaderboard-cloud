# WIP!

# Fluentd docker

Create the fluentd docker
```bash
docker pull fluent/fluentd-kubernetes-daemonset:v1.16.1-debian-cloudwatch-1.2
```

# Fluentd config-map

Now, add the fluent config-map
```bash
kubectl apply -f fluentd-configmap.yaml
```

[ADI: Doesn't exist]

# (Probably have to add a Cloudwatch logging here)


# Permissionss


AWS Cloudwatch permissions. Creates a role and a policy. This role will later be added to the fluent-bit daemonset.
```bash
ROLE_NAME=fluentbit-cloudwatch-beta-leaderboard-10
aws iam create-role --role-name $ROLE_NAME --assume-role-policy-document "file://fluentbit-cloudwatch-role.json"
aws iam put-role-policy --role-name $ROLE_NAME --policy-name=cloudwatch --policy-document file://fluentbit-cloudwatch-policy.json
```

Then, add permissions to the actual fluent-bit daemon-set.
```bash
kubectl apply -f fluentd-rbac.yaml
```

# Daemon-set

```bash
kubectl apply -f fluentd.yaml
```

[ADI removes a shared volume + pulls from alphadrive image]

# Example pod

To test that this worked, we can run a counter pod `counter`

```bash
kubectl apply -f counter.yaml
```

Make sure that the pod is running with
```bash
kubectl get pods
kubectl logs counter
```

# (Optional) Understanding fluentd log collection

To check where are the logs stored in the fluent pod. Enter the fluentd pod using its name
```bash
kubectl get pods -n kube-system
kubectl exec -it -n kube-system <pod-name> -- /bin/bash
```

From there, go to `/var/log`, which is the default storing fodler for fluentd

Once inside that folder, use `ls` to check its contents. You should be seeing these two things:
- A folder named `containers`. Here is where the logs are stored.
- A file named `fluent-containers.log.pos`. This is a file that fluentd uses to keep track of where has it read up to. 
These two items should be mounted on the host to ensure that even if the pod fails, the data is not lost

By entering the `containers` folder and chceking its contents, you should see several `.log` files, one for each pod the DaemonSet is monitoring.

Note: (To understand) This might vary between apps / providers... but they generally have their own directory, which is linked to this `var/log/containers` folder, writting the logs in both.

While these are the default folder that `fluentd` uses, remeber that all if this has been specified inside the `fluentd-configmap.yaml`, at the *pods-fluent.conf*. Specifically at the *path* and *pos_file* variables.

All the explanation above focused on the acquisition of the logs, and the next step is to extract the logs. This extraction is specified by the `file-fluent.conf` at the `fluentd-configmap.yaml`, which does the following:
- `match **`: From all the fluentd sources, choose all of them. In this case `pods-fluent.conf`
- `@type file`: Filter out all the elements that are files
- `path /tmp/file-test.log` write them into this location

# Delete stuff


```bash
docker pull fluent/fluent-bit

ROLE_NAME=fluentbit-beta-leaderboard-10
aws iam create-role --role-name $ROLE_NAME --assume-role-policy-document file://fluentbit_experiments/fluentbit-cloudwatch-role.json
aws iam put-role-policy --role-name $ROLE_NAME --policy-name=cloudwatch --policy-document file://fluentbit_experiments/fluentbit-cloudwatch-policy.json

kubectl apply -f fluentbit-all.yaml
kubectl apply -f counter.yaml
```

```bash
kubectl delete -f fluentbit-configmap.yaml
kubectl delete -f fluentbit-rbac.yaml
kubectl delete -f fluentbit.yaml
kubectl delete -f counter.yaml
```
