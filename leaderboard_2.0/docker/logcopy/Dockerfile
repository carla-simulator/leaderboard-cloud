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

RUN pip3 install \
    requests \
    dictor

COPY run_logcopy.sh /workspace/run_logcopy.sh
COPY run_logcopy.sh /workspace/evalai/generate_results.py
COPY run_logcopy.sh /workspace/evalai/generate_stdout.py

CMD ["/bin/bash"]
