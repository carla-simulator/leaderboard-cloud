FROM python:3.7

WORKDIR /workspace

# Install aws cli v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf awscliv2.zip

RUN pip3 install \
    requests \
    dictor

COPY run_logcopy.sh /workspace/run_logcopy.sh

CMD ["/bin/bash"]
