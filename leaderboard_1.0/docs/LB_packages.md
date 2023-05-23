# Create the Development Setup

## Create the CARLA Package

```bash
make package ARGS="--config=Development"
```

Then, extract the LinuxNoEditor outside of the folder, and rename it to `CARLA_Development`

Import the `Town14` at `carla/Dist`, and once it is finished, remove the *.zip* file

## Create the CARLA Docker

Replace the Dockerfile inside the package with the `Dockerfile_dev` and create the docker

```bash
docker build --force-rm -t carla_dev -f Dockerfile .
```

Push the Docker with 

```bash
$(aws ecr get-login --no-include-email --region us-east-1)
docker tag carla_dev:latest 342236305043.dkr.ecr.us-east-1.amazonaws.com/leaderboard-20-simulator-development:latest
docker push 342236305043.dkr.ecr.us-east-1.amazonaws.com/leaderboard-20-simulator-development:latest
```

## Create the Leaderboard Docker

Change the `.bashrc` to point to the new package egg.

Go to `~/carla-challenge-contents/src/leaderboard_20/make_docker_leaderboard.sh` and change the name of the leaderboard docker to `leaderboard-master-development`, then create it with

```bash
bash ~/carla-challenge-contents/src/leaderboard_20/make_docker_leaderboard.sh
```

Then, push it with 

```bash
$(aws ecr get-login --no-include-email --region us-east-1)
docker tag leaderboard-master-development:latest 342236305043.dkr.ecr.us-east-1.amazonaws.com/leaderboard-20-development:latest
docker push 342236305043.dkr.ecr.us-east-1.amazonaws.com/leaderboard-20-development:latest
```

# Create the Testing Setup

## Create the CARLA Package

```bash
make package
```

Then, extract the LinuxNoEditor outside of the folder, and rename it to `CARLA_Testing`

Import the `Town14` at `carla/Dist`, and once it is finished, remove the *.zip* file

## Create the CARLA Docker

Replace the Dockerfile inside the package with the `Dockerfile_test` and create the docker

```bash
docker build --force-rm -t carla_test -f Dockerfile .
```

Push the Docker with 

```bash
$(aws ecr get-login --no-include-email --region us-east-1)
docker tag carla_test:latest 342236305043.dkr.ecr.us-east-1.amazonaws.com/leaderboard-20-simulator-testing:latest
docker push 342236305043.dkr.ecr.us-east-1.amazonaws.com/leaderboard-20-simulator-testing:latest
```

## Create the Leaderboard Docker

Change the `.bashrc` to point to the new package egg.

Go to `~/carla-challenge-contents/src/leaderboard_20/make_docker_leaderboard.sh` and change the name of the leaderboard docker to `leaderboard-master-testing`, then create it with

```bash
bash ~/carla-challenge-contents/src/leaderboard_20/make_docker_leaderboard.sh
```

Then, push it with 

```bash
$(aws ecr get-login --no-include-email --region us-east-1)
docker tag leaderboard-master-testing:latest 342236305043.dkr.ecr.us-east-1.amazonaws.com/leaderboard-20-testing:latest
docker push 342236305043.dkr.ecr.us-east-1.amazonaws.com/leaderboard-20-testing:latest
```
