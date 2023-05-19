# Logging results to Cloudwatch

With the bare minimum created, it is now time to start adding the functionalities that will help us interact with the cluster. In this sections, we'll be taking a look at Fluentd, a tool meant to collect and extract logging data. In particular, we'll be using Fluentd to collect the results outputed by the CARLA server and the Leaderboard and send them onto Cloudwatch for an easy visualization.

### Fluentd

Fluentd is a DaemonSet, which means that it is a process that kubernetes automatically adds to all available pods, perfect for when we want to extract the logs of any desired part of the cluster. 

In order to decide what information to extract exactly, fluentd uses a ConfigMap, which is divided in 3 parts:
- `source`: in this part we are specifying what logs do we want to extract from the cluster. In other words, this is Fluentd's input.
- `filter`: here we can modify the gotten logs by adding / removing information, changing their format...
- `match`: here we tell Fluentd what to do with the extracted logs.

Our config map looks liket his

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

In the `source` section, we are defining it to be `tail`, meaning to monitor specific files / folders. Which folders? Well that is what the `path` is used for. In this case we monitor the `/var/log/containers` folder, which is where all the *stdout* get saved. More specifically, we filter the submission ones by using `simulator`, `agent` and `logcopy`, which are the names of the containers part of the [submission job](leaderboard_1.0/experiments/exp3.yaml). Lastly, we parse the logs to remove the timestamp, which is automatically added when saving the *stdout* to the `/var/log/containers` folder.

For the filter, we use the `kubernetes_metadata` one, to add a lot of information about the container, pod, namespace...
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

Next, we use the `cloudwatch_logs` type at the `match` section to send the logs to AWS Cloudwatch. The main configuration to take note of here are the AWS region, name of the log group, which are given by the environment variables in the DaemonSet.

One final point about the configuration is that while there is only one type of input and output in our case, this might not be true for other cases. In order to specify what to do with the different sources, they have a `tag` associated to them, which is them compared by the `filter` and `match` names. In our case, everything is set to `kubernetes.*`.

Lastly, several things to mention about the DaemonSet. Remember that it has to have the `fluentd` ServiceAccount associated, as seen at `spec.template.spec.ServiceAccountName`. The container image is `fluent/fluentd-kubernetes-daemonset:v1.16.1-debian-cloudwatch-1.2`, which is the most recent Fluent'd image that containers the Cloudwatch logs output (can be found in their [Dockerhub](https://hub.docker.com/r/fluent/fluentd-kubernetes-daemonset/), searching for *Cloudwatch*), and needs the `K8S_NODE_NAME` environment variables. Lastly, share the ConfigMap volume mount, and the `/var/log` and `/var/lib/docker/containers` are also shared, so that in case of failure, Fluentd knows where to resume its logging from, instead of restarting from scratch.

> Note: [here](https://docs.fluentd.org/input) are the fluentd docs (TODO: Improve this)


### AWS Permissions and RBAC

Before running Fluentd, we have to add the required permissions for it to work. This section is divided in two parts, granting Fluentd permissions to write logs in AWS Cloudwatch, and allowing Fluentd to get access the cluster data.

The first part has actually already been set up, as it is part of the IAM section in the [leaderboard-10-cluster.yaml](leaderboard_1.0/config/leaderboard-10-cluster.yaml) file, but here is how it works. In short, what Fluentd needs in order to access Cloudwatch is to have a service account with an AWS Role associated to it. Instead of creating a permanent role and making this associating manually, we are creating a temporary role, which is creating on cluster creation, deleted on its deletion, and added to a service account of the specified name. This is done at the IAM section, as previously mentioned, and looks like this

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

For the second issue, we can just use the Kubernete's RBAC to add the service account to a ClusterRole

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

### Applying Fluentd to the cluster

Everything that was just explained is already available at the [leaderboard_1.0/config/fluentd.yaml](leaderboard_1.0/config/fluentd.yaml) file, so we only have to apply it to kubernetes

```bash
kubectl apply -f leaderboard_1.0/config/fluentd.yaml
```

and voilà, Fluentd is not set up
