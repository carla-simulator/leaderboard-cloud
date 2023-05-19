FROM ubuntu:20.04

WORKDIR /workspace

ENV CARLA_PYTHON_API_ROOT "/workspace/CARLA"
ENV SCENARIO_RUNNER_ROOT "/workspace/scenario_runner"
ENV LEADERBOARD_ROOT "/workspace/leaderboard"

COPY PythonAPI ${CARLA_PYTHON_API_ROOT}}/PythonAPI
COPY scenario_runner ${SCENARIO_RUNNER_ROOT}
COPY leaderboard ${LEADERBOARD_ROOT}

CMD ["/bin/bash"]
