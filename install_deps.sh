#!/bin/bash
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

# Example for the Intel compilers:
# CC="${INTEL_PATH}/linux/bin/intel64/icc"
# CXX="${INTEL_PATH}/linux/bin/intel64/icpc"
# FC="${INTEL_PATH}/linux/bin/intel64/ifort"

# Example for OSX with clang (fortran disabled):
# CC="clang"
# CXX="clang++"
# FC=

# Compile flags
#==============================

# Example for GNU compilers
CFLAGS="-O3 -fPIC -pthread"
CXXFLAGS="-O3 -fPIC -pthread -std=c++11"
FCFLAGS="-O3 -fPIC -pthread"
OPENMP_CFLAGS="-fopenmp"
OPENMP_CXXFLAGS="-fopenmp"
LDFLAGS="-lpthread -fopenmp"

# Example for Intel compilers, building "fat" binaries that have object code for both
# ivybridge and newer processors as well as KNL with AVX512.
# CFLAGS="-O3 -g -fPIC -xcore-avx2 -axmic-avx512 -pthread"
# CXXFLAGS="-O3 -g -fPIC -xcore-avx2 -axmic-avx512 -pthread -std=c++11"
# FCFLAGS="-O3 -g -fPIC -xcore-avx2 -axmic-avx512 -fexceptions -pthread -heap-arrays 16"
# OPENMP_CFLAGS="-qopenmp"
# OPENMP_CXXFLAGS="-qopenmp"
# LDFLAGS="-lpthread -liomp5"

# Parallel builds
MAKEJ=2


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

# For each of the packages below, you can either tweak the build command or comment out
# the lines completely if you are using some external package.

# GMP / MPFR
#---------------------

# Most Linux systems already have these development libraries installed (needed by
# SuiteSparse below).  They are commented out here by default.  If you are installing
# on a truly bare-bones system or in a container you may need to install these from
# scratch with your custom compilers.

# # libgmp
#
# gmp_version=6.2.0
# gmp_dir=gmp-${gmp_version}
# gmp_pkg=${gmp_dir}.tar.xz
#
# echo "Fetching libgmp"
#
# if [ ! -e ${gmp_pkg} ]; then
#     curl -SL https://ftp.gnu.org/gnu/gmp/${gmp_pkg} -o ${gmp_pkg}
# fi
#
# echo "Building libgmp..."
#
# rm -rf ${gmp_dir}
# tar xf ${gmp_pkg} \
#     && pushd ${gmp_dir} >/dev/null 2>&1 \
#     && CC="${CC}" CFLAGS="${CFLAGS}" \
#     ./configure \
#     --disable-static \
#     --enable-shared \
#     --with-pic \
#     --prefix="${PREFIX}" \
#     && make -j ${MAKEJ} \
#     && make install \
#     && popd >/dev/null 2>&1
#
# # libmpfr
#
# mpfr_version=4.1.0
# mpfr_dir=mpfr-${mpfr_version}
# mpfr_pkg=${mpfr_dir}.tar.xz
#
# echo "Fetching libmpfr"
#
# if [ ! -e ${mpfr_pkg} ]; then
#     curl -SL https://www.mpfr.org/mpfr-current/${mpfr_pkg} -o ${mpfr_pkg}
# fi
#
# echo "Building libmpfr..."
#
# rm -rf ${mpfr_dir}
# tar xf ${mpfr_pkg} \
#     && pushd ${mpfr_dir} >/dev/null 2>&1 \
#     && CC="${CC}" CFLAGS="${CFLAGS}" \
#     ./configure \
#     --disable-static \
#     --enable-shared \
#     --with-pic \
#     --with-gmp="${PREFIX}" \
#     --prefix="${PREFIX}" \
#     && make -j ${MAKEJ} \
#     && make install \
#     && popd >/dev/null 2>&1

# BLAS / LAPACK
#---------------------

# Here we install OpenBLAS by default, but you might use any BLAS / LAPACK
# implementation.  HOWEVER, see the note in the README about MKL conflicts between
# versions used to build TOAST and those installed along with Numpy.

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

# If you commented out the above installation of OpenBLAS, set these lines to the
# link command for BLAS and LAPACK for use by future dependencies below.
BLAS="-L${PREFIX}/lib -lopenblas -lm ${LDFLAGS}"
LAPACK="-L${PREFIX}/lib -lopenblas -lm ${LDFLAGS}"

# Example:  Use MKL instead (and comment out the install of OpenBLAS above)
# BLAS="-L${MKLROOT}/lib/intel64 -lmkl_rt -lm ${LDFLAGS}"
# LAPACK="-L${MKLROOT}/lib/intel64 -lmkl_rt -lm ${LDFLAGS}"

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
    # Put any environment setup here...
    # module load python
    #
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
