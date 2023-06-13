FROM python:3.7

WORKDIR /workspace

RUN apt-get update \
    && apt-get install -y --no-install-recommends jq \
    && rm -rf /var/lib/apt/lists/* 

# Install aws cli v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf awscliv2.zip

ENV CARLA_PYTHON_API_ROOT "/workspace/CARLA"
ENV SCENARIO_RUNNER_ROOT "/workspace/scenario_runner"
ENV LEADERBOARD_ROOT "/workspace/leaderboard"

COPY PythonAPI ${CARLA_PYTHON_API_ROOT}/PythonAPI
COPY scenario_runner ${SCENARIO_RUNNER_ROOT}
COPY leaderboard ${LEADERBOARD_ROOT}

CMD ["/bin/bash"]
