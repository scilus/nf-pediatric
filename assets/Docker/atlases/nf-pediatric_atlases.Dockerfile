ARG FREESURFER_BUILD_IMAGE=ubuntu:22.04
ARG SCILPY_BASE_IMAGE=scilus/scilpy:1.6.0

# Create a stage to build the freesurfer image (only essential scripts).
FROM $FREESURFER_BUILD_IMAGE AS build_freesurfer

ENV LANG=C.UTF-8
ENV DEBIAN_FRONTEND=noninteractive

# Install packages needed for build
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      file \
      git \
      upx \
      wget && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ARG PYTHON_VERSION=3.10

# Fetch install script in docker.
RUN mkdir /install
COPY ./install_freesurfer.sh /install/
RUN ["chmod", "+x", "/install/install_freesurfer.sh"]
SHELL ["/bin/bash", "--login", "-c"]

ARG FREESURFER_URL=default

RUN /install/install_freesurfer.sh /opt --upx --url $FREESURFER_URL
RUN rm /opt/freesurfer/bin/fspython
RUN rm -R /install

# Main stage from scilpy base image.
FROM $SCILPY_BASE_IMAGE AS runtime

ENV LANG=C.UTF-8
ENV DEBIAN_FRONTEND=noninteractive

# Install required packages for freesurfer to dry_run
RUN apt-get update && apt-get install -y --no-install-recommends \
      bc \
      gawk \
      libgomp1 \
      libquadmath0 \
      libglu1-mesa \
      libxt6 \
      libxmu6 \
      libgl1 \
      freeglut3-dev \
      python3.10 \
      wget \
      curl \
      time \
      tcsh && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Installing Parallel
# Installing dependencies.
RUN (wget -O - pi.dk/3 || curl pi.dk/3/) | bash
RUN echo 'will cite' | parallel --citation 1> /dev/null 2> /dev/null &

# Add FreeSurfer and python Environment variables
# DO_NOT_SEARCH_FS_LICENSE_IN_FREESURFER_HOME=true deactivates the search for FS_LICENSE in FREESURFER_HOME
ENV OS=Linux \
    FS_OVERRIDE=0 \
    FIX_VERTEX_AREA="" \
    SUBJECTS_DIR=/opt/freesurfer/subjects \
    FSF_OUTPUT_FORMAT=nii.gz \
    FREESURFER_HOME=/opt/freesurfer \
    PYTHONUNBUFFERED=0 \
    MPLCONFIGDIR=/tmp \
    PATH=/venv/bin:/opt/freesurfer/bin:$PATH \
    MPLCONFIGDIR=/tmp/matplotlib-config \
    DO_NOT_SEARCH_FS_LICENSE_IN_FREESURFER_HOME="true"

COPY --from=build_freesurfer /opt/freesurfer /opt/freesurfer
