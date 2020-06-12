# TOAST Benchmarks

The purpose of this package is to document the performance testing of the TOAST package
on current and new systems.  This includes the installation of dependencies and TOAST
itself, as well as running several example workflows.

## Overview

The TOAST package is a hybrid C++ / Python framework:

https://github.com/hpc4cmb/toast

The required dependencies include several compiled libraries as well as some standard
python packages.  This [toast-bench](https://github.com/hpc4cmb/toast-bench) git repo
includes scripts to install TOAST and its dependencies from scratch given some minimal
external requirements (serial compilers).  Before attempting to install TOAST manually,
please read and understand all the notes below.

## Installation

There are several ways to install TOAST.  Pre-built binary packages are available as pip
wheels and also through the conda-forge channel.  When running benchmarks on a new or
unusual system, you may achieve better performance building TOAST and some or all of the
dependencies from scratch.  However, it can be useful to run the tests with pre-built
packages as a starting point for the performance testing.  To install with binary
packages, see [General installation instructions
here](https://toast-cmb.readthedocs.io/en/latest/install.html).

The rest of this section covers installation of TOAST and its dependencies from source.
The dependencies required by TOAST are:

* A C++11 compiler
* A BLAS / LAPACK installation
* [FFTW](http://fftw.org/) libraries
* [CMake](https://cmake.org/) (>= 3.10)
* Python3 (>= 3.6)
* Python packages:  numpy, scipy, astropy, healpy, h5py, ephem

Additionally, some features of TOAST are only available if other packages are present:

* MPI and mpi4py (for effective parallelism)
* [SuiteSparse](http://faculty.cse.tamu.edu/davis/suitesparse.html) (for atmosphere simulations)
* [libaatm](https://github.com/hpc4cmb/libaatm) (for atmosphere simulations)
* [PySM](https://github.com/healpy/pysm) (for astrophysical sky simulations)
* [libconviqt](https://github.com/hpc4cmb/libconviqt) (for harmonic-space beam convolutions)
* [libmadam](https://github.com/hpc4cmb/libmadam) (for traditional destriping / map-making)

> **WARNING**:  TOAST has some compiled dependencies (LAPACK) which are
> also used from Python (numpy / scipy uses LAPACK).  Your
> numpy / scipy stack must either use a completely different LAPACK than the one
> used to build TOAST or must use an identical LAPACK.

For example, here are some combinations and the result:

TOAST Built With | Python Using | Result
-----------------|--------------|---------
Statically linked OpenBLAS (binary wheels on PyPI) | numpy with any LAPACK | **Works** since TOAST does not load any external LAPACK.
Intel compiler and MKL | numpy with MKL | Broken, **UNLESS** both MKLs are compatible and using Intel threading interface.
GCC and system OpenBLAS | numpy with MKL | **Works**: different libraries are dl-opened by TOAST and numpy.
Intel compiler and MKL | numpy with OpenBLAS | **Works**: different libraries are dl-opened by TOAST and numpy.

### Installing Dependencies with "cmbenv"

The [cmbenv](https://github.com/hpc4cmb/cmbenv) package is a set of scripts to build
from source a variety of packages used in Cosmic Microwave Background (CMB) data
analysis.  cmbenv can install a Python3 conda environment or it can use the default
Python3 on the system to create a virtualenv for installing this software.

This directory includes a script, `install_dependencies.sh` which will download the
cmbenv package and use it to compile all of the TOAST dependencies.  This build process
can be configured with the `config-deps` file, which contains variables for setting
compilers and other system values, and for overriding things like a vendor BLAS / LAPACK
install.  The `config-deps.pkgs` file contains details about which packages should be
built by cmbenv.  This defaults to creating a python3 virtualenv and compiling all
dependencies (including MPICH).  You should edit the config-deps and config-deps.pkgs
files to match your test system.

If you already have some dependencies installed and you are absolutely sure that
everything is ABI compatible, then you can comment out those package lines in the
config-deps.pkgs file.  After editing these files, install the dependencies to a
top-level prefix with: ```bash ./install_dependencies.sh /path/to/prefix ```

Then load this software stack before installing TOAST with:
```bash
source /path/to/prefix/cmbenv_init.sh
source cmbenv
```

Now install TOAST using the provided script.  This parses the same `config-deps` file you made to get options which are passed to CMake:

```bash
./install_toast.sh
```

After this, you can always load the cmbenv environment above and all tools (including TOAST) will be available.

### Manually Installing Dependencies

If you just want to "override" specific dependencies with manually installed versions,
you can comment out the package in the `config-deps.pkgs` file and use the cmbenv tools
mentioned above.

There may be cases where you want to install everything manually.  In this case, you
should ensure the following:

- Your math libraries (LAPACK, FFTW, and SuiteSparse) are binary compatible with each
- other and with your serial compilers.

- Your Python3 installation is recent.  Versions 3.6-3.8 are regularly tested by our
  continuous integration workflows.  If you are using a system Python3, create a
  virtualenv for these benchmarks and activate it.  If you are using a conda-based
  Python3 stack, create a new conda environment for these benchmarks and activate it.

- Some python packages ship with pre-built shared libraries.  When you install these
  packages with pip or conda, these libraries will be placed in your virtualenv or conda
  environment.  You must ensure that the directory containing these libraries is **not**
  in the search path used by the linker (e.g. LD_LIBRARY_PATH).  Often these libraries
  are incompatible with other system libraries and should only be loaded by the python
  packages using them.

- When installing compiled dependencies, these libraries need to be visible to the
  linker when linking the internal TOAST library.  Since these libraries need to be in
  the linker search path, you should **not** install them directly to the virtualenv or
  conda environment prefix you are using for python packages.  Install compiled
  dependencies to another location which you can then put into PATH, LD_LIBRARY_PATH,
  and PYTHONPATH.

Here is an overview of the steps for manually setting up a TOAST test environment.
Since there will be several locations of installed software, I recommend creating a
shell function / alias which adds everything to PATH, LD_LIBRARY_PATH, etc:

1.  Select your serial compilers and any pre-existing versions of BLAS / LAPACK, FFTW,
and SuiteSparse that you would like to use.  Ensure that these are loaded in your shell
environment.

2.  If using MPI, ensure that your MPI installation is loaded in your shell environment.

3.  Determine what Python3 you will be using.  If you are using a system Python3, create
a virtualenv for these benchmarks and activate it.  If you are using a conda-based
Python3 stack, create a new conda environment for these benchmarks and activate it.
**WARNING**: conda installs its own version of a linker.  If you are using a conda
environment, check if the file `compiler_compat/ld` exists in the conda environment
prefix.  If so, remove it or rename it.

4.  Install the following python packages: `numpy`, `scipy`, `matplotlib`, `healpy`,
`astropy`, `pysm3`, `h5py`, `ephem`, `cmake`.  If you are working with a virtualenv,
install these packages with pip.  If using a conda environment, install these with
conda.

5.  Install the `mpi4py` package with pip (not conda).  Read the documentation of that
package to see how to make sure it finds your intended MPI compiler.

6.  Determine where you wish to install compiled dependencies (and TOAST).  Install
compiled dependencies you do not already have:  [FFTW](http://fftw.org/),
[SuiteSparse](http://faculty.cse.tamu.edu/davis/suitesparse.html),
[libaatm](https://github.com/hpc4cmb/libaatm), and optionally
[libconviqt](https://github.com/hpc4cmb/libconviqt) and
[libmadam](https://github.com/hpc4cmb/libmadam).

Now we are ready to install TOAST to the location where we are placing our compiled
packages and thing outside of our virtualenv / conda env.  Go into the source tree and
make a build directory:

```bash
mkdir build
cd build
```

Now run cmake from here.  For example, pretend we are installing TOAST and all our
compiled dependencies to `/path/to/benchmark_libs`.  And pretend we wanted to install
TOAST on a Cray system at NERSC using the Intel compilers and building object code
optimized for both the login nodes and the KNL compute nodes.  We could do this:

```bash
PREFIX=/path/to/benchmark_libs cmake \
    -DCMAKE_C_COMPILER="${CRAYPE_DIR}/bin/cc" \
    -DCMAKE_CXX_COMPILER="${CRAYPE_DIR}/bin/CC" \
    -DCMAKE_C_FLAGS="-O3 -g -fPIC -xcore-avx2 -axmic-avx512 -pthread" \
    -DCMAKE_CXX_FLAGS="-O3 -g -fPIC -xcore-avx2 -axmic-avx512 -pthread -std=c++11" \
    -DPYTHON_EXECUTABLE:FILEPATH=$(which python3) \
    -DBLAS_LIBRARIES=$MKLROOT/lib/intel64/libmkl_rt.so \
    -DLAPACK_LIBRARIES=$MKLROOT/lib/intel64/libmkl_rt.so \
    -DFFTW_ROOT="${PREFIX}" \
    -DAATM_ROOT="${PREFIX}" \
    -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
    -DSUITESPARSE_INCLUDE_DIR_HINTS="${PREFIX}/include" \
    -DSUITESPARSE_LIBRARY_DIR_HINTS="${PREFIX}/lib" \
    -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
    ..
```

And then:

```bash
make -j 4 install
```

## Running the Benchmarks

The benchmark scripts are located within the TOAST package.  From your source checkout,
go into the `examples` directory.  See the README there for more information.  Basically
you download some data files:

```bash
./fetch_data.sh
```

And then generate some job directories with:

```bash
./generate.py
```

To add configurations for new systems, you can add their properties to the top of the
`config.toml` file.  You will probably also need to make a template for the job
submission script.  See the `template_nersc.slurm` and `template_shell.sh` examples.
