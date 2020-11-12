#!/bin/bash
#
# This script installs TOAST using the previously-built dependencies
#
# See the README for more details.
#

# The install PREFIX you used for dependencies.  This will install
# TOAST to the same location.
PREFIX="$(pwd)/toast_stack"

# The version of TOAST to install
VERSION=2.3.12

# Compiler options (should match what you used for dependencies)
CC="icc"
CXX="icpc"
CFLAGS="-O3 -fPIC -pthread"
CXXFLAGS="-O3 -fPIC -pthread -std=c++11"
OPENMP_CXXFLAGS="-qopenmp"

# Dependencies.  We are getting BLAS/LAPACK/FFT support from MKL.
AATM_ROOT="${PREFIX}"
SUITESPARSE_ROOT="${PREFIX}"

# Clone TOAST and checkout desired version
if [ -d toast ]; then
    # We already have a clone of toast, just update
    pushd toast >/dev/null 2>&1
    git checkout master
    git fetch
    git rebase origin/master
else
    git clone https://github.com/hpc4cmb/toast.git
    pushd toast >/dev/null 2>&1
fi
git checkout -B bench ${VERSION}

rm -rf build
mkdir build
pushd build >/dev/null 2>&1

cmake \
    -DCMAKE_C_COMPILER="${CC}" \
    -DCMAKE_CXX_COMPILER="${CXX}" \
    -DCMAKE_C_FLAGS="${CFLAGS}" \
    -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
    -DPYTHON_EXECUTABLE:FILEPATH=$(which python3) \
    -DAATM_ROOT="${AATM_ROOT}" \
    -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
    -DSUITESPARSE_INCLUDE_DIR_HINTS="${SUITESPARSE_ROOT}/include" \
    -DSUITESPARSE_LIBRARY_DIR_HINTS="${SUITESPARSE_ROOT}/lib" \
    -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
    ..

make -j 4 install

popd >/dev/null 2>&1
popd >/dev/null 2>&1
