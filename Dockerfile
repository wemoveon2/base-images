# Build a virtualenv containing necessary system libraries and Python packages 
# for users to install their own packages while also being distroless. 
# * Install python3-venv 
# * Install gcc libpython3-dev to compile C Python modules
# * In the virtualenv: Update pip setuputils and wheel to support building new packages 
# * Export environment variables to use the virtualenv by default
# * Export environment variables needed for CUDA
# * Create a non-root user with minimal privileges and use it
# * Includes /bin/sh in final image for downstream package installation
ARG CUDA_VERSION
FROM nvidia/cuda:${CUDA_VERSION}-base-ubuntu20.04 AS build
ARG PYTHON_VERSION
ARG DRIVER_VERSION
ENV DEBIAN_FRONTEND=noninteractive 
RUN apt-get update && \
    apt-get install --no-install-suggests --no-install-recommends --yes \
    software-properties-common && \
    # Ubuntu 20.04 uses 3.8 as the default Python version, we need 3.11
    add-apt-repository ppa:deadsnakes/ppa && \
    add-apt-repository ppa:graphics-drivers/ppa && \
    apt-get update && \
    apt-get install --no-install-suggests --no-install-recommends --yes \
    python${PYTHON_VERSION} \
    python${PYTHON_VERSION}-venv \
    python${PYTHON_VERSION}-dev \
    gcc \
    libpython3-dev \
    # drivers and nvidia-smi
    nvidia-cuda-toolkit \ 
    nvidia-utils-${DRIVER_VERSION} \
    nvidia-driver-${DRIVER_VERSION} \
    libcap2-bin && \
    python${PYTHON_VERSION} -m venv /venv && \
    /venv/bin/pip install --upgrade pip setuptools wheel && \
    # Create a non-root user with minimal privileges and set file permissions
    adduser --disabled-password --gecos '' appuser && \ 
    apt-get clean && rm -rf /var/lib/apt/lists/* 

FROM gcr.io/distroless/python3-debian12
# files for user profiles
COPY --from=build /etc/passwd /etc/passwd
COPY --from=build /etc/group /etc/group
# needed to call pip directly
COPY --from=build /bin/sh /bin/sh
# virtual env and cuda
COPY --from=build --chown=appuser:appuser /venv /venv
COPY --from=build --chown=appuser:appuser /usr/local/cuda /usr/local/cuda 
# for debugging
COPY --from=build /usr/bin/nvidia-smi /usr/bin/nvidia-smi
# driver libraries
COPY --from=build /usr/lib/x86_64-linux-gnu/libcuda.so* /usr/lib/x86_64-linux-gnu/
COPY --from=build /usr/lib/x86_64-linux-gnu/libnvidia-ml.so* /usr/lib/x86_64-linux-gnu/
# sh cmd validator 
COPY --chmod=555 checker.sh /checker.sh
# need awk for checker.sh
COPY --from=build /usr/bin/awk /usr/bin/awk

# Set environment variables for CUDA
ENV PATH=/usr/local/cuda/bin:${PATH}
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH
ENV CUDA_HOME=/usr/local/cuda

# Set environment variables to use virtualenv by default
ENV VIRTUAL_ENV=/venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"
# Switch to the non-root user
USER appuser
SHELL ["/checker.sh", "-c"]