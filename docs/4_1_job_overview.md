# Job overview

Similar to other Kubernetes elements, a Job is defined by a configuration file, where its requirements are specified. From there, Kubernetes will extract the type of requested instances and create the amount of [Pods](https://kubernetes.io/docs/concepts/workloads/pods/) needed for the Job to successfully run until completion.

This section of the whole pipeline is the one with the most differences when comparing the [Leaderboard 1.0 Job](/leaderboard_1.0/jobs/param-carla-benchmark-job.yaml) and its [Leaderboard_2.0 counterpart](/leaderboard_2.0/jobs/param-carla-benchmark-job.yaml). This is because the job is responsible for setting up all the environment variables used by CARLA and the Leaderboard when running. Some examples would be the difference in _repetitions_ between leaderboards, or the change from _opengl_ to _vulkan_ in the CARLA versions.

## General overview

Diving into the configuration file, it again starts with the two lines that indicate the type of action expected from Kubernetes
```yaml
apiVersion: batch/v1
kind: Job
```

The `metadata` section sets the name of the Job. In this case, isntead of using a specific one, it has been parametrized to allow the usage of the job for multiple parallel submissions. This parametrization is indicated by the `.$`, and will be set by the AWS Step Function.
```yaml
metadata:
  name.$: $.submission.name
```

Moving onto the `spec` section, the `template.spec` indicate the details of the job. The first specifications are that it requires a `g5.12xlarge` instance with the `submission-worker` Service Account, both already defined at the cluster configuration and ready.
```yaml
spec:
    serviceAccountName: submission-worker
    nodeSelector:
    node.kubernetes.io/instance-type: g5.12xlarge
```

Then, the `initContainers` define a group of docker containers that run at the beginning. The other containers defined at the `containers` section will not be initialized until the init containers have completed. Both sections have the same arguments and are the expected ones from docker containers. These include their name along with the image used, and the commands, arguments, environment variables and volume mounts used. The [next section](/docs/4_2_containers_overview.md) will explain the inner working of these containers and more information about the arguments can be found [here](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#Container).

### Routes' parallelization

Due to the synchronous nature of the Leaderboard, the computation of the CARLA server doesn't affect the AV stack's use of resources, as it is always done in sequence. In other words, one will only start once the other has finished. As such, they can be considered as one process that continuously makes use of the instance's resources. Additionally, the CARLA infrastructure has the limitation of only using one GPU, regardless of the amount available by the instance. this has recently changed with the addition of the multi GPU feature for sensors, but it won't be used in this case.

While this seems to go against the use of the `g5.12xlarge` instances, the Leaderboard itself is based on the execution of independent routes, all of which generate results when they finish. As such, the routes used by the CARLA Leaderboards don't need to be run in any specific order, neither in one full execution, or even using the same machine. As long as the results are merged together once they all finish, it's exact execution won't matter.

The sumbission Job makes use of this feature by having a total of 9 containers, which are 4 CARLA simulators, 4 Leaderboards and another one called `logcopy`. Each simulator-agent pair is run in one of the 4 GPUs available in the `g5.12xlarge` instance (selected using the `NVIDIA_VISIBLE_DEVICES` environment variable), and is responsible of 5 out of the 20 total testing routes. Volume mounts are used to share the results of the 4 Leaderboard executions with the `logcopy` container, which is responsible for merging the results into one.

Also note that the default port values can no longer be used as there will be multiple servers running in the same instance. As such, the `CARLA_PORT` environment variable is used to avoid interferences between each pair. The TrafficManager port is also derived from this variable for the same reasons.

### Automatic retries

Another interesting feature of the submission Job is the [pod failure policy](https://kubernetes.io/docs/concepts/workloads/controllers/job/#pod-failure-policy), giving users the capability of handling failed Pods in different ways. By using the `restartPolicy: OnFailure`, Pods that have failed for any reason will automatically be restarted. With this alone, a constantly failing Pod could block the Job forever, which is why Kubernetes provides the `backoffLimit` argument, limiting the amount of restarts to a set value.

Specifically for the submission Job, each element in the simulator-agent pair monitors both its own status as well as its pair one, so that if any of the two fail, they both reset at the same time, resuming from where they left off. The `backoffLimit` has been set up to the value of 8, so that this resume can happen a maximum of four times, as each resume restarts one simulator and one leaderboard, regardless of what caused the failure to appear.
