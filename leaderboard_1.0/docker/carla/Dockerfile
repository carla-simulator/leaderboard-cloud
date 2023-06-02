
FROM nvidia/vulkan:1.1.121-cuda-10.1--ubuntu18.04

RUN apt-key adv --fetch-keys "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/3bf863cc.pub"

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

USER carla
WORKDIR /home/carla

ENV OMP_PROC_BIND="FALSE"
ENV OMP_NUM_THREADS="48"
ENV SDL_VIDEODRIVER="offscreen"
ENV NVIDIA_DRIVER_CAPABILITIES="all"

CMD /bin/bash CarlaUE4.sh -opengl -nosound
