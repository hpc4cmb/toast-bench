# TOAST Benchmarks

The purpose of this package is to document the performance testing of the TOAST package on current and new systems.  This includes the installation of dependencies and TOAST itself, as well as running several example workflows.

## Overview

The TOAST package is a hybrid C++ / Python framework:

https://github.com/hpc4cmb/toast

The required dependencies include several compiled libraries as well as some standard python packages.  This [toast-bench](https://github.com/hpc4cmb/toast-bench) git repo includes scripts to install TOAST and its dependencies from scratch given some minimal external requirements (serial compilers).  Before attempting to install TOAST manually, please read and understand all the notes below.

## Dependencies

The dependencies required by TOAST are:

* A C++11 compiler
* A BLAS / LAPACK installation
* [FFTW](http://fftw.org/) libraries
* [CMake](https://cmake.org/) (>= 3.10)
* Python3 (the newer the better, but >= 3.4 should work)
* Python packages:  numpy, scipy, astropy, healpy

Additionally, some features of TOAST are only available if other packages are present:

* MPI and mpi4py (for effective parallelism)
* [SuiteSparse](http://faculty.cse.tamu.edu/davis/suitesparse.html) (for atmosphere simulations)
* [libaatm](https://github.com/hpc4cmb/libaatm) (for atmosphere simulations)
* [PySM](https://github.com/healpy/pysm) (for astrophysical sky simulations)
* [libconviqt](https://github.com/hpc4cmb/libconviqt) (for harmonic-space beam convolutions)
* [libmadam](https://github.com/hpc4cmb/libmadam) (for traditional destriping / map-making)

It is **absolutely critical** that these dependencies be compiled in a consistent way.  There are multiple ways of accomplishing this, and the following sections cover some ways that are known to work.

> **WARNING**:  TOAST has some compiled dependencies (LAPACK and MPI) which are
> also used from Python (numpy / scipy uses LAPACK and mpi4py uses MPI).  Your mpi4py
> installation must use the same MPI that is used when building TOAST.  Your
> numpy / scipy stack must either use a completely different LAPACK than the one
> used to build TOAST or must use an identical LAPACK.

For example, here are some combinations and the result:

TOAST Built With | Python Using | Result
-----------------|--------------|---------
System / Vendor MPI | mpi4py installed with conda | **Broken**: mpi4py package links to conda-shipped MPI, not system version.
System / Vendor MPI | mpi4py installed manually or with pip | **Works**: compiled extension for mpi4py finds and uses system MPI.
Intel compiler and MKL | numpy with MKL | Broken, **UNLESS** both MKLs are compatible and using Intel threading interface.
GCC and OpenBLAS | numpy with MKL | **Works**: different libraries are dl-opened by TOAST and numpy.
Intel compiler and MKL | numpy with OpenBLAS | **Works**: different libraries are dl-opened by TOAST and numpy.

### Installing Dependencies with "cmbenv"

The [cmbenv](https://github.com/hpc4cmb/cmbenv) package is a set of scripts to build from source a variety of packages used in Cosmic Microwave Background (CMB) data analysis.  cmbenv can install a Python3 conda environment or it can use the default Python3 on the system to create a virtualenv for installing this software.

This directory includes a script, `install_dependencies.sh` which will download the cmbenv package and use it to compile all of the TOAST dependencies.  This build process can be configured with the `config-deps` file, which contains variables for setting compilers and other system values, and for overriding things like a vendor BLAS / LAPACK install.  The `config-deps.pkgs` file contains details about which packages should be built by cmbenv.  This defaults to creating a python3 virtualenv and compiling all dependencies (including MPICH).  You should edit the config-deps and config-deps.pkgs files to match your test system.

If you already have some dependencies installed and you are absolutely sure that everything is ABI compatible, then you can comment out those package lines in the config-deps.pkgs file.  After editing these files, install the dependencies to a top-level prefix with:
```bash
./install_dependencies.sh /path/to/prefix
```

Then load this software stack before installing TOAST with:
```bash
source /path/to/prefix/cmbenv_init.sh
source cmbenv
```

Now continue to installing TOAST in the section below.

### Manually Installing Dependencies

If you just want to "override" specific dependencies with manually installed versions, you can comment out the package in the `config-deps.pkgs` file and use the cmbenv tools mentioned above.

There may be cases where you want to install everything manually.  In this case, you should ensure that:

- Your MPI installation and other math libraries (LAPACK, FFTW, and SuiteSparse) are binary compatible with each other and with your serial compilers.

- Your Python3 installation is recent.  Version 3.6 and 3.7 have received the most testing.  If you are using a system Python3, create a virtualenv for these benchmarks and activate it.  If you are using a conda-based Python3 stack, create a new conda environment for these benchmarks and activate it.

- Some python packages ship with pre-built shared libraries.  When you install these packages with pip or conda, these libraries will be placed in your virtualenv or conda environment.  You must ensure that the directory containing these libraries is **not** in the search path used by the linker (e.g. LD_LIBRARY_PATH).  Often these libraries are incompatible with other system libraries and should only be loaded by the python packages using them.

- When installing compiled dependencies, these libraries need to be visible to the linker when linking the internal TOAST library.  Since these libraries need to be in the linker search path, you should **not** install them directly to the virtualenv or conda environment prefix you are using for python packages.  Install compiled dependencies to another location which you can then put into PATH, LD_LIBRARY_PATH, and PYTHONPATH.

Here is an overview of the steps for manually setting up a TOAST test environment.  Since there will be several locations of installed software, I recommend creating a shell function / alias which adds everything to PATH, LD_LIBRARY_PATH, etc:

1.  Select your serial compilers and any pre-existing versions of BLAS / LAPACK, FFTW, and SuiteSparse that you would like to use.  Ensure that these are loaded in your shell environment.  Also make sure you have a recent CMake (>= 3.10).

2.  If using MPI, ensure that your MPI installation is compatible with your serial compilers and loaded in your shell environment.

3.  Determine what Python3 you will be using.  If you are using a system Python3, create a virtualenv for these benchmarks and activate it.  If you are using a conda-based Python3 stack, create a new conda environment for these benchmarks and activate it.  **WARNING**: conda installs its own version of a linker.  If you are using a conda environment, check if the file `compiler_compat/ld` exists in the conda environment prefix.  If so, remove it or rename it.

4.  Install the following python packages: `numpy`, `scipy`, `matplotlib`, `healpy`, `astropy`, `pysm3`.  If you are working with a virtualenv, install these packages with pip.  If using a conda environment, install these with conda.

5.  Determine where you wish to install compiled dependencies (and TOAST).  Install compiled dependencies you do not already have:  [FFTW](http://fftw.org/), [SuiteSparse](http://faculty.cse.tamu.edu/davis/suitesparse.html), [libaatm](https://github.com/hpc4cmb/libaatm), [libconviqt](https://github.com/hpc4cmb/libconviqt), and [libmadam](https://github.com/hpc4cmb/libmadam).

6.  Install TOAST.  (FIXME: link to docs here).


## Running the Benchmarks

The benchmark scripts are located within the TOAST package.  To run them...

(Update this section after scripts are cleaned up)
