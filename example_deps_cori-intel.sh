#!/bin/bash
#
# Example for installation on cori.nersc.gov.  This assumes that before running
# you do:
#
# module load python
# module load cmake
#
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

# Intel compilers:
CC="${INTEL_PATH}/linux/bin/intel64/icc"
CXX="${INTEL_PATH}/linux/bin/intel64/icpc"
FC="${INTEL_PATH}/linux/bin/intel64/ifort"

# Compile flags
#==============================

CFLAGS="-O3 -g -fPIC -pthread"
CXXFLAGS="-O3 -g -fPIC -pthread -std=c++11"
FCFLAGS="-O3 -g -fPIC -fexceptions -pthread -heap-arrays 16"
OPENMP_CFLAGS="-qopenmp"
OPENMP_CXXFLAGS="-qopenmp"
LDFLAGS="-lpthread -liomp5"

# Parallel builds
MAKEJ=8


# Environment:  put the install prefix into our environment while
# running this script.

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


# PACKAGES
#==============================

BLAS="-L${MKLROOT}/lib/intel64 -lmkl_rt -lm ${LDFLAGS} -ldl"
LAPACK="-L${MKLROOT}/lib/intel64 -lmkl_rt -lm ${LDFLAGS} -ldl"

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

# Now print out some reminder information about loading these tools

echo "
TOAST dependencies have been installed to:

${PREFIX}

You need to load this location into your environment before 
installing TOAST.  For example, here are a couple of bash 
functions that do this in a robust way:

# Put these in your ~/.bashrc or similar.

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
    # Environment setup
    module load python
    module load cmake
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

Then do:

%> load_toast

"
