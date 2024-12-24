FROM scilus/scilpy:dev AS base

# Set a stage for mrtrix3 build.
FROM ubuntu:22.04 AS mrtrix3_build

ARG MRTRIX3_GIT_TAG="3.0.4"
ARG MRTRIX3_CONFIGURE_FLAGS=""
ARG MRTRIX3_BUILD_FLAGS="-persistent -nopaginate"

RUN apt-get -qq update && \
    apt-get install -yq --no-install-recommends \
    libeigen3-dev \
    wget \
    make \
    cmake \
    g++ \
    libfftw3-dev \
    libgl1-mesa-dev \
    libpng-dev \
    libqt5opengl5-dev \
    libqt5svg5-dev \
    libtiff5-dev \
    python3 \
    qtbase5-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

ARG MAKE_JOBS=4
WORKDIR /opt/
RUN wget -O mrtrix3.tar.gz "https://github.com/MRtrix3/mrtrix3/archive/refs/tags/3.0.4.tar.gz" --no-check-certificate && \
    tar -xf mrtrix3.tar.gz && \
    rm mrtrix3.tar.gz && \
    cd mrtrix3-3.0.4 && \
    python3 ./configure ${MRTRIX3_CONFIGURE_FLAGS} && \
    NUMBER_OF_PROCESSORS=${MAKE_JOBS} python3 ./build ${MRTRIX3_BUILD_FLAGS} && \
    rm -rf tmp

# Set the runtime image.
FROM base AS runtime

# Install runtime dependencies.
RUN apt-get -qq update && \
    apt-get install -yq --no-install-recommends \
    imagemagick \
    binutils \
    dc \
    jq \
    less \
    libfftw3-single3 \
    libfftw3-double3 \
    libgl1-mesa-glx \
    libgomp1 \
    liblapack3 \
    libpng16-16 \
    libqt5core5a \
    libqt5gui5 \
    libqt5network5 \
    libqt5svg5 \
    libqt5widgets5 \
    libquadmath0 \
    libtiff5-dev \
    python3 \
    python3-distutils \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Copy the MRtrix3 binaries.
COPY --from=mrtrix3_build /opt/mrtrix3-3.0.4 /opt/mrtrix3-3.0.4

ENV PATH="/opt/mrtrix3-3.0.4/bin:$PATH"
