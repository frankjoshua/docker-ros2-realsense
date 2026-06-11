# syntax=docker/dockerfile:1.4

##
#   Multi-Arch ROS2 + Intel RealSense Dockerfile
#   Works for: linux/amd64 and linux/arm64
#   Base: frankjoshua/ros2:humble (ROS Humble)
##

ARG BASE_IMAGE=frankjoshua/ros2:humble
FROM ${BASE_IMAGE} AS base

LABEL maintainer="Joshua Frank <josh@joshfrank.com>"
ARG ROS_DISTRO=humble
ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive

# ============================================================
# Stage 1 – Build librealsense (multi-arch safe)
# ============================================================
FROM base AS librealsense-build

RUN apt-get update && apt-get install -y \
    build-essential cmake git curl pkg-config \
    libusb-1.0-0-dev libudev-dev libgtk-3-dev \
    libglfw3-dev libgl1-mesa-dev libglu1-mesa-dev \
    ca-certificates python3 python3-dev \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src

# Fetch the latest tagged version of librealsense
RUN set -eux; \
    LIBRS_GIT_TAG=$(git -c 'versionsort.suffix=-' \
        ls-remote --exit-code --refs --sort='version:refname' \
        --tags https://github.com/IntelRealSense/librealsense '*.*.*' \
        | tail -n1 | cut -d'/' -f3); \
    LIBRS_VERSION=${LIBRS_GIT_TAG#"v"}; \
    echo "Building librealsense version: $LIBRS_VERSION"; \
    curl -sL https://codeload.github.com/IntelRealSense/librealsense/tar.gz/refs/tags/v${LIBRS_VERSION} -o librealsense.tar.gz; \
    tar -zxf librealsense.tar.gz; \
    rm librealsense.tar.gz; \
    ln -s /usr/src/librealsense-${LIBRS_VERSION} /usr/src/librealsense

WORKDIR /usr/src/librealsense

# Fix: disable all example + OpenGL builds to avoid missing target errors
RUN mkdir build && cd build && \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/opt/librealsense \
        -DCMAKE_CXX_FLAGS="--param ggc-min-expand=20 --param ggc-min-heapsize=131072" \
        -DBUILD_EXAMPLES=OFF \
        -DBUILD_GRAPHICAL_EXAMPLES=OFF \
        -DBUILD_PYTHON_BINDINGS:BOOL=TRUE \
        -DFORCE_RSUSB_BACKEND=ON \
        -DCHECK_FOR_UPDATES=OFF \
        -DBUILD_NETWORK_DEVICEFW=OFF \
        -DBUILD_WITH_OPENGL=OFF \
        -DBUILD_WITH_CUDA=OFF \
        -DENABLE_LTO=OFF && \
    make -j1 && make install && ldconfig

# ============================================================
# Stage 2 – Clone realsense-ros workspace
# ============================================================
FROM base AS ros2-src

WORKDIR /root/ros2_ws/src
RUN git clone https://github.com/IntelRealSense/realsense-ros.git -b ros2-development

# ============================================================
# Stage 3 – Final ROS + RealSense image
# ============================================================
FROM base AS final

ARG ROS_DISTRO=humble
ARG TARGETARCH
ENV PYTHONPATH=${PYTHONPATH}:/usr/local/lib

# Copy librealsense runtime
COPY --from=librealsense-build /opt/librealsense /usr/local/
COPY --from=librealsense-build /usr/src/librealsense/config/99-realsense-libusb.rules /etc/udev/rules.d/99-realsense-libusb.rules

# Copy workspace source
WORKDIR /root/ros2_ws
COPY --from=ros2-src /root/ros2_ws/src ./src

# Build realsense-ros
RUN if [ "$TARGETARCH" = "amd64" ]; then \
        echo "Installing prebuilt RealSense ROS packages for AMD64"; \
        apt-get update && apt-get install -y \
          ros-${ROS_DISTRO}-realsense2-* ros-${ROS_DISTRO}-librealsense2-* && \
        rm -rf /var/lib/apt/lists/*; \
    else \
        echo "Building realsense-ros from source for ARM64"; \
        apt-get update && apt-get install -y python3-rosdep && \
        rosdep init || true; \
        rosdep update && \
        rosdep install --from-paths src --ignore-src -r -y --skip-keys=librealsense2 && \
        . /opt/ros/${ROS_DISTRO}/setup.sh && \
        MAKEFLAGS=-j1 CXXFLAGS="--param ggc-min-expand=20 --param ggc-min-heapsize=131072" \
          colcon build --symlink-install --executor sequential && \
        rm -rf /var/lib/apt/lists/*; \
    fi

# Final setup
RUN udevadm control --reload-rules && udevadm trigger || true
COPY ros_entrypoint.sh /ros_entrypoint.sh
RUN chmod +x /ros_entrypoint.sh

ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["/bin/bash","-i","-c","ros2 launch realsense2_camera rs_launch.py"]
