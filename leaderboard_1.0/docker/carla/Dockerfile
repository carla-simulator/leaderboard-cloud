
# run the docker container as:
#
# sudo -E docker run --rm --gpus all -it --net=host carla:latest /bin/bash

FROM nvidia/vulkan:1.1.121-cuda-10.1--ubuntu18.04

RUN rm /etc/apt/sources.list.d/cuda.list
RUN rm /etc/apt/sources.list.d/nvidia-ml.list

RUN packages='libsdl2-2.0 xserver-xorg libvulkan1' \
	&& apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y $packages --no-install-recommends \
    && VULKAN_API_VERSION=`dpkg -s libvulkan1 | grep -oP 'Version: [0-9|\.]+' | grep -oP '[0-9|\.]+'` && \
	mkdir -p /etc/vulkan/icd.d/ && \
	echo \
	"{\
		\"file_format_version\" : \"1.0.0\",\
		\"ICD\": {\
			\"library_path\": \"libGLX_nvidia.so.0\",\
			\"api_version\" : \"${VULKAN_API_VERSION}\"\
		}\
	}" > /etc/vulkan/icd.d/nvidia_icd.json \
	&& rm -rf /var/lib/apt/lists/*

RUN useradd -m carla

COPY --chown=carla:carla . /home/carla
COPY run_carla.sh /home/carla/run_carla.sh

USER carla
WORKDIR /home/carla

# Select the video driver between offsreen and x11
# x11 is recommended for vulkan support
ENV SDL_VIDEODRIVER=x11

# you can also run CARLA in -opengl mode
CMD /bin/bash CarlaUE4.sh -vulkan