
FROM ubuntu:20.04

RUN packages='libsdl2-2.0 xserver-xorg libvulkan1 libomp5' && apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y $packages --no-install-recommends

RUN useradd -m carla

COPY --chown=carla:carla . /home/carla

USER carla
WORKDIR /home/carla

ENV OMP_PROC_BIND="FALSE"
ENV OMP_NUM_THREADS="48"
ENV SDL_VIDEODRIVER="x11"
ENV NVIDIA_DRIVER_CAPABILITIES="all"

CMD /bin/bash CarlaUE4.sh -RenderOffScreen -nosound
