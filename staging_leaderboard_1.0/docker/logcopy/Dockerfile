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
COPY evalai/generate_results.py /workspace/evalai/generate_results.py
COPY evalai/generate_stdout.py /workspace/evalai/generate_stdout.py
COPY evalai/generate_metadata.py /workspace/evalai/generate_metadata.py

CMD ["/bin/bash"]
