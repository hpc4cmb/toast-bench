# TOAST Benchmarks

The purpose of this package is to document the performance testing of the TOAST package on current and new systems.  This includes the installation of dependencies and TOAST itself, as well as running several example workflows.

## Overview

The TOAST package is a hybrid C++ / Python framework:

https://github.com/hpc4cmb/toast

The required dependencies include several compiled libraries as well as some standard python packages.  Before attempting to install TOAST with specialized compilers, etc, please read and understand all the notes below about dependencies.

## Dependencies

The dependencies required by TOAST are:

* A C++11 compiler
* A BLAS / LAPACK installation
* FFTW libraries
* CMake
* Python3 (the newer the better, but >= 3.4 should work)
* Python packages:  numpy, scipy, astropy, healpy

Additionally, some features of TOAST are only available if other packages are present:

* MPI (for parallelism)
* SuiteSparse (for atmosphere simulations)
* PySM (for astrophysical sky simulations)
* libconviqt (for harmonic-space beam convolutions)
* libmadam (for traditional destriping / map-making)






Instructions and scripts for running TOAST benchmarks
