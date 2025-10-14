# syntax=docker/dockerfile:1.4
ARG BASE_IMAGE=frankjoshua/ros2:latest
FROM ${BASE_IMAGE} AS base

LABEL maintainer="Joshua Frank <josh@joshfrank.com>"
ARG ROS_DISTRO=humble
ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive

# ============================================================
# Stage 1 – Build librealsense (ARM-safe)
# ============================================================
FROM base AS librealsense-build

RUN apt-get update && apt-get install -y \
    git cmake build-essential pkg-config \
    libusb-1.0-0-dev libudev-dev \
    libgtk-3-dev libglfw3-dev libgl1-mesa-dev libglu1-mesa-dev \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt/librealsense
RUN git clone --depth=1 https://github.com/IntelRealSense/librealsense.git .

RUN mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release \
             -DBUILD_EXAMPLES=OFF \
             -DFORCE_RSUSB_BACKEND=ON \
             -DCHECK_FOR_UPDATES=OFF \
             -DBUILD_NETWORK_DEVICEFW=OFF && \
    make -j2 && make install && ldconfig

# ============================================================
# Stage 2 – Prepare realsense-ros workspace (clone only)
# ============================================================
FROM base AS ros2-src

WORKDIR /root/ros2_ws/src
RUN git clone https://github.com/IntelRealSense/realsense-ros.git -b ros2-development

# ============================================================
# Stage 3 – Final image
# ============================================================
FROM base AS final

ARG ROS_DISTRO=humble
ARG TARGETARCH

# Copy built librealsense (for ARM64)
COPY --from=librealsense-build /usr/local /usr/local

# Udev rules
RUN echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="8086", MODE:="0666", GROUP="plugdev"' \
    > /etc/udev/rules.d/99-realsense-libusb.rules && \
    udevadm control --reload-rules && udevadm trigger || true

WORKDIR /root/ros2_ws
COPY --from=ros2-src /root/ros2_ws/src ./src

RUN if [ "$TARGETARCH" = "amd64" ]; then \
        echo "Installing RealSense prebuilt packages for AMD64"; \
        apt-get update && apt-get install -y \
          ros-${ROS_DISTRO}-realsense2-* ros-${ROS_DISTRO}-librealsense2-* && \
        rm -rf /var/lib/apt/lists/*; \
    else \
        echo "Building realsense-ros from source for ARM64"; \
        apt-get update && \
        rosdep update && \
        rosdep install --from-paths src --ignore-src -r -y --skip-keys=librealsense2 && \
        rm -rf /var/lib/apt/lists/* && \
        . /opt/ros/${ROS_DISTRO}/setup.sh && \
        colcon build --symlink-install; \
    fi

COPY ros_entrypoint.sh /ros_entrypoint.sh
RUN chmod +x /ros_entrypoint.sh

ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["/bin/bash","-i","-c","ros2 launch realsense2_camera rs_launch.py"]
