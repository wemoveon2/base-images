# Build a virtualenv containing necessary system libraries and Python packages 
# for users to install their own packages while also being distroless. 
# * Install python3-venv 
# * Install gcc libpython3-dev to compile C Python modules
# * In the virtualenv: Update pip setuputils and wheel to support building new packages 
# * Export environment variables to use the virtualenv by default
# * Create a non-root user with minimal privileges and use it
ARG TARGET_PLATFORM
FROM --platform=$TARGET_PLATFORM ubuntu:22.04 AS build
ARG PYTHON_VERSION
ENV DEBIAN_FRONTEND=noninteractive 
RUN apt-get update && \
    apt-get install --no-install-suggests --no-install-recommends --yes \
    software-properties-common \
    gpg-agent && \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install --no-install-suggests --no-install-recommends --yes \
    python${PYTHON_VERSION} \
    python${PYTHON_VERSION}-venv \
    python${PYTHON_VERSION}-dev \
    gcc \
    libpython3-dev \
    libcap2-bin && \
    python${PYTHON_VERSION} -m venv /venv && \
    /venv/bin/pip install --disable-pip-version-check --upgrade pip setuptools wheel && \
    # Create a non-root user with minimal privileges and set file permissions
    adduser --disabled-password --gecos '' appuser && \ 
    ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 && \
    apt-get clean && rm -rf /var/lib/apt/lists/* 

ARG TARGET_PLATFORM
FROM --platform=$TARGET_PLATFORM gcr.io/distroless/python3-debian12:latest
ARG PYTHON_VERSION
# files for user profiles
COPY --from=build /etc/passwd /etc/passwd
COPY --from=build /etc/group /etc/group
# needed to call pip directly
COPY --from=build /bin/sh /bin/sh
# virtual env
COPY --from=build --chown=appuser:appuser /venv /venv
# we must overwrite the python binary to use the virtualenv since distroless uses 3.11 and we might
# be using another version
COPY --from=build /usr/bin/python${PYTHON_VERSION} /usr/bin/python${PYTHON_VERSION}
COPY --from=build /usr/bin/python3 /usr/bin/python3 
COPY --from=build /usr/lib/python${PYTHON_VERSION} /usr/lib/python${PYTHON_VERSION}
# sh cmd validator 
COPY --chmod=555 checker.sh /checker.sh
# need awk for checker.sh
COPY --from=build /usr/bin/awk /usr/bin/awk

# Set environment variables to use virtualenv by default
ENV VIRTUAL_ENV=/venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"
# Switch to the non-root user
USER appuser
SHELL ["/checker.sh", "-c"]