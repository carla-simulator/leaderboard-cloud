# Saving the logs

To finish the preparation of the cluster, it is generally recommended to add functionalities that will help with the recollection of information about the instances inside the cluster. While the submission job already has several steps to send their data into AWS S3 and AWS DynamoDB, these are only meant to be used as storage element, and using them for debugging purposes tend to not be the best approach. AWS provides a tool for exactly this purpose, AWS Cloudwatch, which can be connected to the Leaderboard cluster using [FluentD](https://www.fluentd.org/).

## Fluentd

Fluentd is an open source data collector meant to allow users to unify their data into their desired format. This means that it is designed to gather information from different parts of the application, in our case the cluster, transform it to any desired format, and send it somewhere for easy viewing of the logs.

Ton run FluentD, a configuration file is used ([Leaderboard 1.0 link](/leaderboard_1.0/config/fluentd.yaml) and [Leaderboard 2.0 link](/leaderboard_2.0/config/fluentd.yaml)), which can be applied to the cluster with:
```bash
kubectl apply -f config/fluentd.yaml
```

The next sections have a detailed analysis of FluentD's configuration file, which is divided in three parts, a ConfigMap, the DaemonSet, and the AWS Permissions and RBAC.

### ConfigMap

Starting with the ConfigMap, this section is responsible of setting the exact behavior of FluentD. Focusing on the `data` section, it is divided in 3 parts:
- **source**: This part specifies what logs to extract from the cluster.
- **filter**: The filter modifies the logs by adding information, removing it, or changing the format.
- **match**: Defines what to do with the extracted logs.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluentd-config
  namespace: kube-system
  labels:
    k8s-app: fluentd
data:
  fluent.conf: |
    <source>
      @type tail
      @id in_tail_container_logs
      path /var/log/containers/*simulator*.log, /var/log/containers/*agent*.log, /var/log/containers/*logcopy*.log, /var/log/containers/*private-contents*.log
      pos_file "/var/log/fluentd-containers.log.pos"
      tag "kubernetes.*"
      read_from_head true
      <parse>
        @type regexp
        expression /^(?<time>.+) (?<stream>stdout|stderr)( (?<logtag>.))? (?<log>.*)$/
      </parse>
    </source>

    <filter kubernetes.**>
      @type kubernetes_metadata
      @id filter_kube_metadata
    </filter>

    <match kubernetes.**>
      @type cloudwatch_logs
      @id out_cloudwatch_logs
      region "#{ENV['AWS_REGION']}"
      log_group_name "#{ENV['LOG_GROUP_NAME']}"
      aws_instance_profile_credentials_retries 5
      auto_create_stream true
      use_tag_as_stream true
      json_handler yajl
      log_rejected_request true
    </match>
```

In the `source` section, the `tail` type tells FluentD to monitor files and folders. The exact ones are given by the `path` parameter. In this case, Fluentd monitors the `/var/log/containers` folder, which is where all the *stdout* get saved. More specifically, only the ones that include `simulator`, `agent` and `logcopy` are checked, which are the names of the containers part of the submission job, along with the `private-contents`, the initial container used to inject the private map and routes onto the agent ([Leaderboard 1.0 job](/leaderboard_1.0/jobs/param-carla-benchmark-job.yaml) and [Leadeberboard 2.0 job](/leaderboard_2.0/jobs/param-carla-benchmark-job.yaml)). Lastly, the timestamp is removed with the `regexp` parsing.

For the filter, the `kubernetes_metadata` adds a lot of information about the container, and its Kubernetes execution. It transforms each line into a json with information about the container id that created that log, the pod in which this container is running, the kubernetes namespace, and many others.

Next, the `cloudwatch_logs` type at the `match` section makes Fluentd send the logs to AWS Cloudwatch. Note that the AWS region and the log group name are given by the environment variables in the DaemonSet.

One final point about the configuration is the tagging functionality. While there is only one type of input and output in this configuration map, this might not be true for other cases. To specify the different loggings, each `source` has a `tag` associated to them. This is then compared to the `filter` and `match` names, and only those that match will be applied. This configuration map sets everything to `kubernetes.*`.

### DaemonSet

As for Fluentd's DaemonSet, it has the `fluentd` service account linked, and uses the `fluent/fluentd-kubernetes-daemonset:v1.16.1-debian-cloudwatch-1.2`, which is the most recent image that has the Cloudwatch logs output (can be found in their [Dockerhub](https://hub.docker.com/r/fluent/fluentd-kubernetes-daemonset/), searching for *Cloudwatch*), which needs the `K8S_NODE_NAME` environment variable. The ConfigMap is passed to the DaemonSet via a volume, and uses `AWS_REGION` and `LOG_GROUP_NAME` environment variables to set up the Cloudwatch `match`. The other two volumes, `/var/log` and `/var/lib/docker/containers` should always be shared so that in case of failure, FluentD knows where to resume its logging from, instead of restarting from scratch.

### AWS Permissions and RBAC

The last step is to add the required permissions for Fluentd to work. This is done in two parts.

The first part is the creation of the ServiceAccount, and it has already been done, as it is part of the Leaderboard cluster configuration file. There, a ServiceAccount with the `fluentd` has been created, which has been link to the DaemonSet with the `serviceAccount` and `serviceAccountName` sections

Then, this ServiceAccount can be link with a ClusterRole using Kubernetes's RBAC.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: fluentd-role
rules:
  - apiGroups:
      - ""
    resources:
      - namespaces
      - pods
      - nodes
    verbs:
      - get
      - list
      - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: fluentd-role-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: fluentd-role
subjects:
  - kind: ServiceAccount
    name: fluentd
    namespace: kube-system
```