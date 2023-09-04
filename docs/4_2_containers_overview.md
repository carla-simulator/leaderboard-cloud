# Containers overview

Let's now take a look at each of the docker containers part of the Job, starting with the `private-contents` initial containers, and followed by the other three runtime containers, `simulator`, `agent` and `logcopy`.

## Private Contents

When starting the Job, the container that is triggered first is the `private-contents` one. This docker has been designed with several functions in mind.

First of all, the docker image used contains all the secret contents used by the agents, such as the testing routes that the AV stack will navigate through. This content is copied onto a shared volume so that it can be implanted onto the agent's docker later on.

The docker image additionally contains the official CARLA PythonAPI, ScenarioRunner and Leaderboard used, which are also extracted in a shared volume. Similar to the private contents, thes will also be passed onto the agent container, overwritting the ones also part of the docker, and removing any possible modifications done to it.

Lastly, due to the nature of init containers, the `private-contents` docker is also used to initialize the folders where all the results are stored. This folder is a shareed volume that is either created or, in the case of a resumed submission, downloaded from S3. Note that for the latter, the `container-status` foler is emptied, to avoid interferences between the current and previous run.

```bash
cp -r ${LEADERBOARD_ROOT}/* /tmp/leaderboard/
cp -r ${SCENARIO_RUNNER_ROOT}/* /tmp/scenario_runner/
cp -r ${CARLA_PYTHON_API_ROOT}/* /tmp/CARLA/

if [ -z $RESUME ]; then
    echo "Detected a normal run, creating log files"
    mkdir -m 0777 -p /tmp/logs/agent/agent{1..4}
    mkdir -m 0777 -p /tmp/logs/simulator
    mkdir -m 0777 -p /tmp/logs/logcopy
    mkdir -m 0777 -p /tmp/logs/containers-status
    mkdir -m 0777 -p /tmp/logs/evalai
else
    echo "Detected a resume, download log files from S3, and removing the container status data"
    aws s3 rm s3://${S3_BUCKET}/${SUBMISSION_ID}/containers-status --recursive
    aws s3 sync s3://${S3_BUCKET}/${SUBMISSION_ID} /tmp/logs
    mkdir -m 0777 -p /tmp/logs/containers-status
fi
```

## Simulator and agent

Moving onto the simulator and agent, it is important to understand that each simulator-agent pair is synchronized so that the two dockers work in tandem. This is achieved by sharing a volume mount between the two, and the `logcopy`, where all dockers create files to communicate that a specific action has happened. These files are all empty, and only their name is used which is defined at the top of both dockers.

With the use of the `ID` variable, the different pairs can use the same folder without interference between them. The `CRASH_ID` one is needed to differentiate between runs when a docker restarts due to a crash.

Starting with the general overview of each container, the `simulator` docker runs the CARLA server process in the background, and then starts monitoring the shared folder as well as the server process. For the `agent` docker, it does a similar thing, running the Leaderboard in the background and monitoring it. Additionally, the docker stores all the Leaderboard output and the agent results in another shared volume, for later use by the `logcopy`. Regardless of what happens while running the docker, both the simulator and the agent will create a file, and only when both files are created, will the simulator-agent dockers finish.

During a normal submission, the Leaderboard process will automatically end, and the docker will create the `AGENT_DONE_FILE`. This will then be detected by the simulator, which will create the `SIMULATOR_DONE_FILE` file, and both dockers will end.

In case of a server crash, the simulator will create a `SIMULATOR_CRASH_FILE`, which the agent will detect and react by stopping the Leaderboard and creating the `AGENT_CRASH_FILE` file, exitting both dockers with a failure. This will trigger the restart policy of the Job, if the `backoffLimit` isn't exceeded, and both dockers will be restarted. The leaderboard will automatically run with the *RESUME* flag if a previous `AGENT_CRASH_FILE` is detected.

Lastly, in case of a cancelled submission, the `logcopy` will be the one creating the `SIMULATION_CANCEL_FILE` which will force both `simulator` and `agent` to stop their processes and exit.

## Logcopy

The last container is the `logcopy` which is responsible for gathering the information created by all the previous containers, parsing it and sending it to AWS for storage and EvalAI to view the results. This is done periodically during the simulation, sending partial results until the simulation has finished.

Starting with the agent results, the `logcopy` container is responsible for merging the results of the four Leaderboard agents into one. This is then used by several scripts to parse the results into something that EvalAI accepts and sent to the frontend. 

Additionally, all the information collected throughout the simulation is stored into S3. This includes all the server logs, the output of all the dockers, including the `logcopy` itself, and the files generated for EvalAI.

Lastly, the `logcopy` container finishes when either all the `DONE_FILE` files have been created (four `SIMULATOR_DONE_FILE` and four `AGENT_DONE_FILE`), or when the user cancels the submission from the frontend.

