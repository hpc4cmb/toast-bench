#!/bin/bash
#
# This is a template for calling CMake and is used by the
# install_toast.sh script.  This is not designed for manual
# use.
#
cmake \
    -DCMAKE_C_COMPILER="@CC@" \
    -DCMAKE_CXX_COMPILER="@CXX@" \
    -DMPI_C_COMPILER="@MPICC@" \
    -DMPI_CXX_COMPILER="@MPICXX@" \
    -DCMAKE_C_FLAGS="@CFLAGS@" \
    -DCMAKE_CXX_FLAGS="@CXXFLAGS@" \
    -DPYTHON_EXECUTABLE:FILEPATH=$(which python3) \
    -DBLAS_LIBRARIES="@BLAS@" \
    -DLAPACK_LIBRARIES="@LAPACK@" \
    -DFFTW_ROOT="${CMBENV_AUX_ROOT}" \
    -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
    -DSUITESPARSE_INCLUDE_DIR_HINTS="${CMBENV_AUX_ROOT}/include" \
    -DSUITESPARSE_LIBRARY_DIR_HINTS="${CMBENV_AUX_ROOT}/lib" \
    -DCMAKE_INSTALL_PREFIX="${CMBENV_AUX_ROOT}" \
    ..
