
FROM ubuntu:22.04
ENV FS_LICENSE="/opt/freesurfer-dev/license.txt" \
    SUBJECTS_DIR="/ext/fs-subjects" \
    FS_INFANT_MODEL="/opt/fs-infant-model" \
    SSCNN_MODEL_DIR="/opt/fs-infant-model/sscnn_skullstrip" \
    OS="Linux" \
    PATH="/opt/niftyreg-master/bin:/opt/freesurfer-pkg/mni/current/bin:/opt/freesurfer-dev/bin:/opt/freesurfer-dev/fsfast/bin:/opt/freesurfer-dev/tktools:/opt/freesurfer-dev/mni/bin:/usr/local/bin:$PATH" \
    FREESURFER_HOME="/opt/freesurfer-dev" \
    FREESURFER="/opt/freesurfer-dev" \
    PERL5LIB="/opt/freesurfer-pkg/mni/current/share/perl5" \
    LOCAL_DIR="/opt/freesurfer-dev/local" \
    FSFAST_HOME="/opt/freesurfer-dev/fsfast" \
    FMRI_ANALYSIS_DIR="/opt/freesurfer-dev/fsfast" \
    FSF_OUTPUT_FORMAT="nii.gz" \
    FUNCTIONALS_DIR="/opt/freesurfer-dev/sessions" \
    PYTHONPATH="/opt/freesurfer-dev/python/packages" \
    FS_OVERRIDE="0" \
    FIX_VERTEX_AREA="" \
    FS_DISABLE_LANG="1" \
    FS_TIME_ALLOW="0" \
    MINC_BIN_DIR="/opt/freesurfer-pkg/mni/current/bin" \
    MINC_LIB_DIR="/opt/freesurfer-pkg/mni/current/lib" \
    MNI_DIR="/opt/freesurfer-pkg/mni" \
    MNI_DATAPATH="/opt/freesurfer-pkg/mni/current/data" \
    MNI_PERL5LIB="/opt/freesurfer-pkg/mni/current/share/perl5" \
    CNYBCH_TEMPLATE_SUBJECTS_DIR="/opt/fs-infant-model/CNYBCH" \
    CNYBCH_SUBJECTS="Template1 Template2 Template3 Template4 Template5 Template6 Template7 Template8 Template9 Template10 Template11 Template12 Template13 Template14 Template15 Template16 Template17 Template18 Template19 Template20 Template21 Template22 Template23 Template24 Template25 Template26" \
    CNYBCH_AGES="9 7 6 5 18 12 0 0 3 8 10 10 18 4 2 14 3 16 0 12 0 15 5 17 16 0" \
    CNYBCH_GMWM_SUBJECTS="Template5 Template6 Template8 Template10 Template13 Template18 Template20 Template22" \
    CNYBCH_GMWM_AGES="18 12 0 8 18 16 12 15" \
    CNYBCH_NEONATES="Template7 Template8 Template19 Template21 Template26" \
    CNYBCH_NEONATEAGES="3 4 1 2 4" \
    CNYBCH_AROUNDONE="Template11 Template12 Template6 Template20 Template16" \
    CNYBCH_AROUNDONEAGES="10 10 12 12 14"
ARG TARGETARCH
RUN apt-get update -qq \
    && apt-get install -y software-properties-common \
    && add-apt-repository ppa:ubuntu-toolchain-r/test \
    && apt-get update -qq \
    && apt-get install -y -q --no-install-recommends \
           bc \
           binutils \
           bzip2 \
           ca-certificates \
           cmake \
           coreutils \
           curl \
           g++-11 \
           gcc-11 \
           gcc-11-base \
           gfortran-11 \
           libgfortran5 \
           git \
           git-annex \
           libbz2-dev \
           libfreetype6-dev \
           libgfortran-11-dev \
           libglib2.0-0 \
           libglu1-mesa-dev \
           libgomp1 \
           libjpeg-dev \
           libopenblas-dev \
           libsqlite3-dev \
           libssl-dev \
           libtool \
           libtool-bin \
           libx11-dev \
           libxaw7-dev \
           libxi-dev \
           libxml2-utils \
           libxmu-dev \
           libxmu-headers \
           libxmu6 \
           libxt-dev \
           libxt6 \
           libffi-dev \
           zlib1g-dev \
           libreadline-dev \
           libhdf5-dev \
           llvm \
           make \
           perl \
           pkg-config \
           sudo \
           tar \
           tcsh \
           unzip \
           uuid-dev \
           vim-common \
           wget \
    && rm -rf /var/lib/apt/lists/* \
    # -------------------------------------------------------------------------
    && git config --global user.email "CI@example.com" \
    && git config --global user.name "CI" \
    # Switch to gcc 11
    # -------------------------------------------------------------------------
    && update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 100 \
    && update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-11 100 \
    && update-alternatives --install /usr/bin/gfortran gfortran /usr/bin/gfortran-11 100 \
    # Make a staging directory, we don't want to use /tmp since it doesn't play nice with singularity
    # See: https://github.com/ReproNim/neurodocker/issues/246
    # -------------------------------------------------------------------------
    && mkdir -p /stage \
    # Python  v3.9.22
    # -------------------------------------------------------------------------
    && curl -sSL --retry 5 https://www.python.org/ftp/python/3.9.22/Python-3.9.22.tgz | tar -xz -C /stage \
    && cd /stage/Python-3.9.22 \
    && ./configure --enable-optimizations --with-ensurepip=install \
    && make -j8 \
    && make install \
    && cd / \
    && rm -rf /stage/Python-3.9.22 \
    && export PATH="/usr/local/bin:$PATH" \
    && /usr/local/bin/python3 -m ensurepip --upgrade \
    && pip3 install --no-cache-dir --upgrade pip setuptools wheel Cython hatchling cmake \
    && sync \
    # Cmake v3.31.7 (must be > v3.6.8)
    # -------------------------------------------------------------------------
    && if [ "$TARGETARCH" = "arm64" ]; then \
        wget https://github.com/Kitware/CMake/releases/download/v3.31.7/cmake-3.31.7-linux-aarch64.sh -q -O /stage/cmake-install.sh; \
        else \
            wget https://github.com/Kitware/CMake/releases/download/v3.31.7/cmake-3.31.7-linux-x86_64.sh -q -O /stage/cmake-install.sh; \
        fi \
    && chmod u+x /stage/cmake-install.sh \
    && mkdir -p /usr/share/cmake-3.31.7 \
    && /stage/cmake-install.sh --skip-license --prefix=/usr/share/cmake-3.31.7 \
    && CMAKE_BINPATH=`which cmake` \
    && rm -rf $CMAKE_BINPATH \
    && ln -s /usr/share/cmake-3.31.7/bin/cmake $CMAKE_BINPATH \
    && rm /stage/cmake-install.sh \
    # Install Zlib
    # ----------------------------------------------------------------
    && wget https://zlib.net/zlib-1.3.1.tar.gz -O zlib-1.3.1.tar.gz \
    && tar -xzf zlib-1.3.1.tar.gz \
    && cd zlib-1.3.1 \
    && ./configure \
    && make -j8 \
    && make install \
    && cd ../ \
    && rm -rf zlib-1.3.1 zlib-1.3.1.tar.gz \
    # Source build ITK-5.4.0
    # ----------------------------------------------------------------
    && mkdir -p /opt/freesurfer-pkg \
    && mkdir -p /opt/freesurfer-dev \
    && wget -q -c http://surfer.nmr.mgh.harvard.edu/pub/data/fspackages/prebuilt/centos7-packages.tar.gz -O - | tar -xz -C /opt/freesurfer-pkg \
    && mv /opt/freesurfer-pkg/packages/* /opt/freesurfer-pkg \
    && rm -rf /opt/freesurfer-pkg/itk \
    && curl -sSL --retry 5 https://github.com/InsightSoftwareConsortium/ITK/releases/download/v5.4.0/InsightToolkit-5.4.0.tar.gz | tar -xz \
    && cd InsightToolkit-5.4.0 \
    && mkdir build \
    && cd build \
    && cmake .. \
        -DCMAKE_CXX_STANDARD=17 \
        -DCMAKE_CXX_STANDARD_REQUIRED=ON \
        -DCMAKE_CXX_EXTENSIONS=OFF \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_EXAMPLES=OFF \
        -DITK_BUILD_DEFAULT=OFF \
        -DITKGroup_Core=ON \
        -DITKGroup_Filtering=ON \
        -DITKGroup_Segmentation=ON \
        -DITKGroup_IO=ON \
        -DModule_AnisotropicDiffusionLBR=ON \
        -DBUILD_TESTING=OFF \
        -DITK_USE_SSE2=OFF \
        -DCMAKE_INSTALL_PREFIX=/opt/freesurfer-pkg/itk/5.4.0 \
    && make -j8 \
    && make install \
    && cd ../../ \
    && rm -rf InsightToolkit-5.4.0 \
    # Source install SAMSEG
    # ----------------------------------------------------------------
    && git clone --branch dev https://github.com/freesurfer/samseg.git /stage/samseg \
    && cd /stage/samseg \
    && git reset --hard 54864dc \
    && git submodule init \
    && git submodule update \
    && export ITK_DIR="/opt/freesurfer-pkg/itk/5.4.0/lib/cmake/ITK-5.4/" \
    && if [ "$TARGETARCH" = "arm64" ]; then \
        sed -i 's/-msse2//g; s/-mfpmath=sse//g' /stage/samseg/gems/CMakeLists.txt; \
        sed -i 's/-msse2//g; s/-mfpmath=sse//g' /stage/samseg/samseg/cxx/CMakeLists.txt; \
        fi \
    && pip3 install . \
    # Compile FreeSurfer TODO: Fix the endif in recon-all-clinical.sh
    # ----------------------------------------------------------------
    && rm -rf /opt/freesurfer-pkg/packages \
    && echo "Cloning..." \
    && echo "   remote:      "https://github.com/freesurfer/freesurfer.git \
    && echo "   branch:      "dev \
    && echo "   commit:      "7b818d3 \
    && echo "   destination: "/stage/freesurfer/freesurfer-dev \
    && git clone --branch dev --single-branch https://github.com/freesurfer/freesurfer.git /stage/freesurfer/freesurfer-dev \
    && cd /stage/freesurfer/freesurfer-dev \
    && git reset --hard 7b818d3 \
    && cd / \
    && if [ "$TARGETARCH" = "arm64" ]; then \
        mkdir -p /stage/freesurfer/freesurfer-dev/thirdparty/sse2neon; \
        curl -L https://raw.githubusercontent.com/DLTcollab/sse2neon/master/sse2neon.h -o /stage/freesurfer/freesurfer-dev/thirdparty/sse2neon/sse2neon.h; \
        export CXXFLAGS="$CXXFLAGS -I/stage/freesurfer/freesurfer-dev/thirdparty/sse2neon"; \
        export CFLAGS="$CFLAGS -I/stage/freesurfer/freesurfer-dev/thirdparty/sse2neon"; \
        cp /stage/freesurfer/freesurfer-dev/thirdparty/sse2neon/sse2neon.h /stage/freesurfer/freesurfer-dev/include/; \
        find /stage/freesurfer/freesurfer-dev -type f \( -name '*.cpp' -o -name '*.c' -o -name '*.h' -o -name '*.hpp' \) -exec sed -i \
            -e 's|#include <emmintrin.h>|#if defined(__aarch64__)\n#include "sse2neon.h"\n#else\n#include <emmintrin.h>\n#endif|' \
            -e 's|#include <xmmintrin.h>|#if defined(__aarch64__)\n#include "sse2neon.h"\n#else\n#include <xmmintrin.h>\n#endif|' \
            {} + ;\
        sed -i '1i set(CMAKE_TRY_COMPILE_TARGET_TYPE "STATIC_LIBRARY")' /stage/freesurfer/freesurfer-dev/CMakeLists.txt; \
        sed -i 's/-msse2//g; s/-mfpmath=sse//g' /stage/freesurfer/freesurfer-dev/gems/CMakeLists.txt; \
        export GFORTRAN_LIBRARIES="/usr/lib/gcc/aarch64-linux-gnu/11/libgfortran.so"; \
        export LAPACK_LIBRARIES="/usr/lib/aarch64-linux-gnu/libopenblas.so"; \
        export DBLAS_LIBRARIES="/usr/lib/aarch64-linux-gnu/libopenblas.so"; \
    fi \
    && cd /stage/freesurfer/freesurfer-dev \
    && sed -i '186 i endif' /stage/freesurfer/freesurfer-dev/recon_all_clinical/recon-all-clinical.sh \
    && cmake \
        -DCMAKE_CXX_STANDARD=17 \
        -DCMAKE_CXX_STANDARD_REQUIRED=ON \
        -DCMAKE_CXX_EXTENSIONS=OFF \
        -DCMAKE_CXX_FLAGS="-I/stage/freesurfer/freesurfer-dev/thirdparty/sse2neon" \
        -DZLIB_LIBRARY=/usr/local/lib/libz.so \
        -DZLIB_INCLUDE_DIR=/usr/local/include \
        -DCMAKE_INSTALL_PREFIX=/opt/freesurfer-dev \
        -DUSER_SAMSEG_PATH=/stage/samseg \
        -DBUILD_GUIS=OFF \
        -DMINIMAL=OFF \
        -DFREEVIEW_LINEPROF=OFF \
        -DCMAKE_DISABLE_FIND_PACKAGE_PETSC=ON \
        -DINFANT_MODULE=OFF \
        -DWARNING_AS_ERROR=OFF \
        -DFS_PACKAGES_DIR=/opt/freesurfer-pkg \
        -DINSTALL_PYTHON_DEPENDENCIES=OFF \
        -DDISTRIBUTE_FSPYTHON=OFF \
        -DINTEGRATE_SAMSEG=ON \
        -DMARTINOS_BUILD=OFF \
        -DGEMS_BUILD_EXECUTABLES=OFF \
        -DCMAKE_CXX_COMPILER=/usr/bin/g++ \
        -DCMAKE_CXX_COMPILER_AR=/usr/bin/ar \
        -DCMAKE_CXX_COMPILER_RANLIB=/usr/bin/ranlib \
        -DCMAKE_CXX_FLAGS="-fPIC -fpermissive" \
        -DCMAKE_C_COMPILER=/usr/bin/gcc \
        -DCMAKE_C_COMPILER_AR=/usr/bin/ar \
        -DCMAKE_C_COMPILER_RANLIB=/usr/bin/ranlib \
        -DCMAKE_C_FLAGS="-fPIC" \
        -DBUILD_PYTHON_SUPPORT=ON \
        -DPYTHON_EXECUTABLE=/usr/local/bin/python3 \
        -DPYTHON_INCLUDE_DIR=/usr/local/include/python3.9 \
        -DPYTHON_LIBRARY=/usr/local/lib/libpython3.9.so \
        /stage/freesurfer/freesurfer-dev \
    && make -j4 \
    # Install python reqs
    # ----------------------------------------------------------------
    && sed -i 's/torch==2\.1\.2+cpu/torch==2.1.2/' /stage/freesurfer/freesurfer-dev/python/requirements-build.txt \
    && pip3 install -r /stage/freesurfer/freesurfer-dev/python/requirements-build.txt \
    # Setup annex remote
    # ----------------------------------------------------------------
    && cd /stage/freesurfer/freesurfer-dev \
    && git remote add datasrc https://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/repo/annex.git \
    && git fetch datasrc \
    && git annex enableremote datasrc || true \
    # Pull from annex and install
    # (`make install` will fail if `git annex get` isn't run)
    # ----------------------------------------------------------------
    && cd /stage/freesurfer/freesurfer-dev \
    && git annex get -q . \
    && git annex unlock \
    && make install \
    # Setup mount points
    # ----------------------------------------------------------------
    && mkdir -p /ext/fs-subjects \
    && mkdir -p /opt/fs-infant-model \
    # Dev tools
    #   - jupyter relies on `libsqlite3-dev` being present before python is compiled
    #   - the /stage dir isn't deleted (to facilitate recompile/install/test)
    #   - awscli is installed (todo, best place for this?)
    # ----------------------------------------------------------------
    && rm -rf /stage \
    && rm -rf \
        /opt/freesurfer-dev/average/AAN \
        /opt/freesurfer-dev/average/BrainstemSS \
        /opt/freesurfer-dev/average/HippoSF \
        /opt/freesurfer-dev/average/PALS_B12.readme \
        /opt/freesurfer-dev/average/ThalamicNuclei \
        /opt/freesurfer-dev/average/*.tif \
        /opt/freesurfer-dev/average/samseg \
        /opt/freesurfer-dev/average/mni_icbm152_nlin_asym_09c \
        /opt/freesurfer-dev/average/mult-comp-cor \
        /opt/freesurfer-dev/average/Choi_JNeurophysiol12_MNI152 \
        /opt/freesurfer-dev/average/Buckner_JNeurophysiol11_MNI152 \
        /opt/freesurfer-dev/average/Yeo_Brainmap_MNI152 \
        /opt/freesurfer-dev/average/Yeo_JNeurophysiol11_MNI152 \
        /opt/freesurfer-dev/bin/freeview \
        /opt/freesurfer-dev/diffusion \
        /opt/freesurfer-dev/matlab \
        /opt/freesurfer-dev/models/easyreg* \
        /opt/freesurfer-dev/sessions \
        /opt/freesurfer-dev/fsfast \
        /opt/freesurfer-dev/fsafd \
        /opt/freesurfer-dev/models/synthmorph* \
        /opt/freesurfer-dev/subjects/bert \
        /opt/freesurfer-dev/subjects/V1_average \
        /opt/freesurfer-dev/subjects/cvs_avg35 \
        /opt/freesurfer-dev/subjects/cvs_avg35_inMNI152 \
        /opt/freesurfer-dev/subjects/fsaverage3 \
        /opt/freesurfer-dev/subjects/fsaverage4 \
        /opt/freesurfer-dev/subjects/fsaverage5 \
        /opt/freesurfer-dev/subjects/fsaverage6 \
        /opt/freesurfer-dev/subjects/fsaverage_sym \
        /opt/freesurfer-dev/subjects/lh.EC_average \
        /opt/freesurfer-dev/subjects/rh.EC_average \
        /opt/freesurfer-dev/subjects/sample* \
        /opt/freesurfer-dev/trctrain

