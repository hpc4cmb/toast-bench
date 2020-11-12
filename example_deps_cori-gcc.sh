#!/bin/bash
#
# Example for installation on cori.nersc.gov with gcc.  This assumes that before running
# you do:
#
# module swap PrgEnv-intel PrgEnv-gnu
# module load python
# module load cmake
#
# This script installs some compiled dependencies needed by TOAST.  You should edit
# the values in this script to match your system and what dependencies you would like
# to build from scratch.
#
# See the README for more details.
#

# Install prefix
#==============================

PREFIX="$(pwd)/toast_stack"

# Serial compilers
#==============================

# Example for the GNU compilers:
CC="gcc"
CXX="g++"
FC="gfortran"

# Compile flags
#==============================

CFLAGS="-O3 -fPIC -pthread"
CXXFLAGS="-O3 -fPIC -pthread -std=c++11"
FCFLAGS="-O3 -fPIC -pthread"
OPENMP_CFLAGS="-fopenmp"
OPENMP_CXXFLAGS="-fopenmp"
LDFLAGS="-lpthread -fopenmp"

# Parallel builds
MAKEJ=8


# Environment:  put the install prefix into our environment while
# running this script.

pysite=$(python3 --version 2>&1 | sed -e "s#Python \(.*\)\.\(.*\)\..*#\1.\2#")

mkdir -p "${PREFIX}/bin"
mkdir -p "${PREFIX}/include"
mkdir -p "${PREFIX}/lib"
if [ ! -e "${PREFIX}/lib64" ]; then
    ln -s "${PREFIX}/lib" "${PREFIX}/lib64"
fi

if [ "x${CPATH}" = "x" ]; then
    export CPATH="${PREFIX}/include"
else
    export CPATH="${PREFIX}/include:${CPATH}"
fi

if [ "x${LD_LIBRARY_PATH}" = "x" ]; then
    export LD_LIBRARY_PATH="${PREFIX}/lib"
else
    export LD_LIBRARY_PATH="${PREFIX}/lib:${LD_LIBRARY_PATH}"
fi

if [ "x${PYTHONPATH}" = "x" ]; then
    export PYTHONPATH="${PREFIX}/lib"
else
    export PYTHONPATH="${PREFIX}/lib/python${pysite}/site-packages:${PYTHONPATH}"
fi


# PACKAGES
#==============================

# BLAS / LAPACK
#---------------------

# Install Openblas

openblas_version=0.3.10
openblas_dir=OpenBLAS-${openblas_version}
openblas_pkg=${openblas_dir}.tar.gz

echo "Fetching OpenBLAS..."

if [ ! -e ${openblas_pkg} ]; then
    curl -SL https://github.com/xianyi/OpenBLAS/archive/v${openblas_version}.tar.gz -o ${openblas_pkg}
fi

echo "Building OpenBLAS..."

rm -rf ${openblas_dir}
tar xzf ${openblas_pkg} \
    && pushd ${openblas_dir} >/dev/null 2>&1 \
    && make USE_OPENMP=1 NO_SHARED=0 \
    MAKE_NB_JOBS=${MAKEJ} \
    CC="${CC}" FC="${FC}" DYNAMIC_ARCH=1 \
    COMMON_OPT="${CFLAGS}" FCOMMON_OPT="${FCFLAGS}" \
    LDFLAGS="${LDFLAGS}" \
    && make NO_SHARED=0 PREFIX="${PREFIX}" install \
    && popd >/dev/null 2>&1


BLAS="-L${PREFIX}/lib -lopenblas -lm ${LDFLAGS}"
LAPACK="-L${PREFIX}/lib -lopenblas -lm ${LDFLAGS}"

# FFTW
#---------------------

fftw_version=3.3.8
fftw_dir=fftw-${fftw_version}
fftw_pkg=${fftw_dir}.tar.gz

echo "Fetching FFTW..."

if [ ! -e ${fftw_pkg} ]; then
    curl -SL http://www.fftw.org/${fftw_pkg} -o ${fftw_pkg}
fi

echo "Building FFTW..."

rm -rf ${fftw_dir}
tar xzf ${fftw_pkg} \
    && pushd ${fftw_dir} >/dev/null 2>&1 \
    && CC="${CC}" CFLAGS="${CFLAGS}" \
    ./configure \
    --enable-threads \
    --disable-static \
    --enable-shared \
    --prefix="${PREFIX}" \
    && make -j ${MAKEJ} \
    && make install \
    && popd >/dev/null 2>&1

# libaatm
# ---------------------

aatm_version=1.0.9
aatm_dir=libaatm-${aatm_version}
aatm_pkg=${aatm_dir}.tar.gz

echo "Fetching libaatm..."

if [ ! -e ${aatm_pkg} ]; then
    curl -SL "https://github.com/hpc4cmb/libaatm/archive/${aatm_version}.tar.gz" -o "${aatm_pkg}"
fi

echo "Building libaatm..."

rm -rf ${aatm_dir}
tar xzf ${aatm_pkg} \
    && pushd ${aatm_dir} >/dev/null 2>&1 \
    && mkdir -p build \
    && pushd build >/dev/null 2>&1 \
    && cmake \
    -DCMAKE_C_COMPILER="${CC}" \
    -DCMAKE_CXX_COMPILER="${CXX}" \
    -DCMAKE_C_FLAGS="${CFLAGS}" \
    -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
    -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
    -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
    .. \
    && make -j ${MAKEJ} install \
    && popd >/dev/null 2>&1 \
    && popd >/dev/null 2>&1

# SuiteSparse
# ---------------------

ssparse_version=5.8.1
ssparse_dir=SuiteSparse-${ssparse_version}
ssparse_pkg=${ssparse_dir}.tar.gz

echo "Fetching SuiteSparse..."

if [ ! -e ${ssparse_pkg} ]; then
    curl -SL https://github.com/DrTimothyAldenDavis/SuiteSparse/archive/v${ssparse_version}.tar.gz -o ${ssparse_pkg}
fi

echo "Building SuiteSparse..."

rm -rf ${ssparse_dir}
tar xzf ${ssparse_pkg} \
    && pushd ${ssparse_dir} >/dev/null 2>&1 \
    && make library JOBS=${MAKEJ} \
    CC="${CC}" CXX="${CXX}" \
    CFLAGS="${CFLAGS}" CXXFLAGS="${CXXFLAGS}" AUTOCC=no \
    GPU_CONFIG="" CFOPENMP="${OPENMP_CXXFLAGS}" \
    LAPACK="${LAPACK}" BLAS="${BLAS}" \
    && cp -a ./include/* "${PREFIX}/include/" \
    && cp -a ./lib/* "${PREFIX}/lib/" \
    && find . -name "*.a" -exec cp -a '{}' "${PREFIX}/lib/" \; \
    && popd >/dev/null 2>&1

# Install some python packages to ensure we have them and that
# they are recent.

python3 -m pip install --prefix "${PREFIX}" astropy healpy ephem

# Make a shell snippet to load the tools

echo "
# Load this software stack into your environment by sourcing this file:
#
#   %>  . init.sh
#   %>  load_toast
#

prepend_env () {
    # This function is needed since trailing colons
    # on some environment variables can cause major
    # problems...
    local envname=\$1
    local envval=\$2
    if [ \"x\${!envname}\" = \"x\" ]; then
        export \${envname}=\"\${envval}\"
    else
        export \${envname}=\"\${envval}\":\${!envname}
    fi
}

load_toast () {
    # Location of the software stack
    prefix=${PREFIX}
    # Python major/minor version for site-packages
    pysite=\$(python3 --version 2>&1 | sed -e \"s#Python \(.*\)\.\(.*\)\..*#\1.\2#\")
    # Add software stack to the environment
    prepend_env \"PATH\" \"\${prefix}/bin\"
    prepend_env \"CPATH\" \"\${prefix}/include\"
    prepend_env \"LD_LIBRARY_PATH\" \"\${prefix}/lib\"
    prepend_env \"PYTHONPATH\" \"\${prefix}/lib/python\${pysite}/site-packages\"
}
" > "${PREFIX}/init.sh"

# Now print out some reminder information about loading these tools

echo "
TOAST dependencies have been installed to:

${PREFIX}

You need to load this location into your environment before
installing TOAST.  You can do this by sourcing the generated
shell file:

%>  . ${PREFIX}/init.sh

"
