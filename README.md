# Intel RealSense driver in Docker [![](https://img.shields.io/docker/pulls/frankjoshua/ros2-realsense)](https://hub.docker.com/r/frankjoshua/ros2-realsense) [![CI](https://github.com/frankjoshua/docker-ros2-realsense/workflows/CI/badge.svg)](https://github.com/frankjoshua/docker-ros2-realsense/actions)

## Description

Runs the Intel RealSense RGB-D camera driver (realsense-ros) in a Docker container — prebuilt Humble packages on amd64, librealsense + realsense-ros built from source on arm64. `--network=host` is needed for ROS 2 DDS discovery. --ipc=host is needed to allow shared memory between processes for dds when multiple containers are on the same machine. --pid=host is needed for unique guid in dds to avoid possible id conflicts.

This repo is mostly an example of how to build a multi architecture docker container with ROS (Robotic Operating System). Github Actions is used to build multi-architecture images using `docker buildx` for amd64 (x86 Desktop PC) and arm64 (Jetson). This is for the purpose of developing locally on a work pc or laptop. Then being able to transfer your work to an embedded device with a high level of confidence of success.

## Example

```
docker run -it \
    --network=host \
    --ipc=host \
    --pid=host \
    frankjoshua/ros2-realsense
```

## Building

Use [build.sh](build.sh) to build the docker containers.

<br>Local builds are as follows:

```
./build.sh -t frankjoshua/ros2-realsense -l
```

To build for both amd64 and arm64. Also push to docker hub.
```
./build.sh -t frankjoshua/ros2-realsense -p
```

## Template

This repo is a GitHub template. Just change the repo name in [.github/workflows/ci.yml](.github/workflows/ci.yml) and edit [Dockerfile](Dockerfile) and [README.md](README.md) to taste.

## Testing

Github Actions expects the DOCKERHUB_USERNAME and DOCKERHUB_TOKEN variables to be set in your environment.

## License

Apache 2.0

## Author Information

Joshua Frank [@frankjoshua77](https://www.twitter.com/@frankjoshua77)
<br>
[http://roboticsascode.com](http://roboticsascode.com)
