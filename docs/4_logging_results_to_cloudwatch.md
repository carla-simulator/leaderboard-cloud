# Logging results to Cloudwatch

With the bare minimum created, it is now time to start adding the functionalities that will help us interact with the cluster. Let's start with Fluentd, a tool meant to collect and extract logging data. In particular, Fluentd will collect the results outputed by the CARLA server and the Leaderboard and send them onto Cloudwatch for an easy visualization.

### Fluentd

Fluentd is an open source data collector meant to allow users to unify their data into their desired format. For more information, the next section focuses on the details of the [fluentd configuration file](../config/fluentd.yaml), which can be applied to the cluster with:
```bash
kubectl apply -f config/fluentd.yaml
```

### (Optional) Understanding Fluentd

Fluentd is a DaemonSet, which means that it is a process that Kubernetes automatically adds to all available pods, perfect for when we want to extract the logs of any desired part of the cluster. Apart from the DaemonSet

Users can decide how to use Fluentd by specifying a ConfigMap, which is divided in 3 parts:
- **source**: This part specifies what logs to extract from the cluster.
- **filter**: The filter modifies the logs by adding information, removing it, or changing the format
- **match**: Match defined what will Fluentd do with the extracted logs.

The cluster's configuration map looks like this:

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
      path /var/log/containers/*simulator*.log, /var/log/containers/*agent*.log, /var/log/containers/*logcopy*.log
      pos_file "/var/log/fluentd-containers.log.pos"
      tag "kubernetes.*"
      read_from_head true
      <parse>
        @type regexp
        expression /^(?<time>.+) (?<stream>stdout|stderr)( (?<logtag>.))? (?<log>.*)$/
      </parse>
    </source>

    <filter kubernetes.*>
      @type kubernetes_metadata
      @id filter_kube_metadata
    </filter>

    <match kubernetes.*>
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

In the `source` section, the `tail` type tells FluentD to monitor files and folders. The exact ones are given by the `path` paramterer. In this case, Fluentd monitors the `/var/log/containers` folder, which is where all the *stdout* get saved. More specifically, only the ones that include `simulator`, `agent` and `logcopy` are checked, which are the names of the containers part of the [submission job](../experiments/exp3.yaml). Lastly, the timestamp is remove with the `regexp` parsing.

For the filter, the `kubernetes_metadata` one adds a lot of information about the container, and its Kubernetes execution
```json
{
    "stream": ...,
    "logtag": ...,
    "log": "Actual logs here",
    "docker": {
        "container_id": ...
    },
    "kubernetes": {
        "container_name": ...,
        "namespace_name": ...,
        "pod_name": ...,
        "container_image": ...,
        "container_image_id": ...,
        "pod_id": ...,
        "pod_ip": ...,
        "host": ...,
        "labels": {
            "controller-uid": ...,
            "job-name": ...
        },
        "master_url": ...,
        "namespace_id": ...,
        "namespace_labels": {
            "kubernetes.io/metadata.name": ...
        }
    }
}
```

Next, the `cloudwatch_logs` type at the `match` section makes Fluentd send the logs to AWS Cloudwatch. Note that the AWS region and the log group name are given by the environment variables in the DaemonSet.

One final point about the configuration is the tagging functionality. While there is only one type of input and output in this configuration map, this might not be true for other cases. To specify what to do with the different sources, they have a `tag` associated to them. This is then compared to the `filter` and `match` names, and only those that match will be applied. This configuration map sets everything to `kubernetes.*`.

This configuration map is then linked with the DaemonSet via a volume.

As for Fluentd's DaemonSet, it has the `fluentd` service account linked, and uses the `fluent/fluentd-kubernetes-daemonset:v1.16.1-debian-cloudwatch-1.2`, which is the most recent image that has the Cloudwatch logs output (can be found in their [Dockerhub](https://hub.docker.com/r/fluent/fluentd-kubernetes-daemonset/), searching for *Cloudwatch*), which needs the `K8S_NODE_NAME` environment variable. The configuration map is passed to the Daemon set via a volume, and uses `AWS_REGION` and `LOG_GROUP_NAME` environment variables. The other two volumes, `/var/log` and `/var/lib/docker/containers`, are shared so that in case of failure, Fluentd knows where to resume its logging from, instead of restarting from scratch.

### AWS Permissions and RBAC

The last step is to add the required permissions for Fluentd to work. This section is divided in two parts, granting Fluentd permissions to write logs in AWS Cloudwatch, and allowing Fluentd to get access the cluster data.

The first part has already been set up, as it is part of the IAM section in the [leaderboard-cluster.yaml](../config/leaderboard-cluster.yaml) file, but here is how it works. In short, what Fluentd needs in order to access Cloudwatch is to have a service account with an AWS Role associated to it. Instead of creating a permanent role and making this associating manually, a temporary role is created during the cluster's lifetime, which is automatically associated to a service account of the specified name. This is done at the IAM section, and looks like this:

```yaml
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
```

With this, a new service account called `fluentd` is created, which has the necessary AWS permissions to create a log stream and put events in it.

For the second issue, Kubernete's RBAC can be used to link the service account with a ClusterRole

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