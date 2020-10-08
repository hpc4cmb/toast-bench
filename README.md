# TOAST Benchmarks

The purpose of this package is to document the performance testing of the TOAST package
on current and new systems.  This includes the installation of dependencies and TOAST
itself, as well as running several example workflows.

## Overview

The TOAST package is a hybrid C++ / Python framework:

https://github.com/hpc4cmb/toast

The required dependencies include several compiled libraries as well as some standard
python packages.  This [toast-bench](https://github.com/hpc4cmb/toast-bench) git repo
documents running TOAST benchmarks using a variety of installation methods, from
pre-built binaries to running scripts that build all dependencies with custom compiler
options.

## Running the Benchmarks

After installing TOAST (see below), you should have the `toast_benchmark.py` script in
your executable search path.  Although this script will run without MPI, you should have
the `mpi4py` package installed in order to do any useful tests.  The
`toast_benchmark.py` script will automatically choose one of several pre-set workflow
sizes based on the size and configuration of the job you run.  You can see the small
number of commandline options with:

```
toast_benchmark.py --help

usage: toast_benchmark.py [-h] [--node_mem_gb NODE_MEM_GB] [--dry_run DRY_RUN]

Run a TOAST workflow scaled appropriately to the MPI communicator size and available memory.

optional arguments:
  -h, --help            show this help message and exit
  --node_mem_gb NODE_MEM_GB
                        Use this much memory per node in GB
  --dry_run DRY_RUN     Comma-separated total_procs,node_procs to simulate.
```

The `--node_mem_gb` option is used to override the amount of RAM to use on each node, in
case the amount detected by `psutil` gives incorrect results.  The `--dry_run` option
will simulate the job setup given the total number of MPI processes and the number of
processes per node.  These are specified as two numbers specified by a comma.  

### Dry Run Tests

Before launching real jobs, it is useful to test the job setup in dry-run mode.  You can
do these tests serially.  The script will select the workflow size based on your
commandline values to the `--dry_run` option and will create the job output directory,
configuration log file, and some input data files.  So this is a way of checking that
everything makes sense before submitting the actual job.  For example, to simulate the
job setup for running 1024 MPI processes with 16 processes per node (so 64 nodes), on a
system with 90GB of RAM per node, you can do:

```
toast_benchmark.py --node_mem_gb 90 --dry_run 1024,16

TOAST INFO: TOAST version = 2.3.8.dev9
TOAST INFO: Using a maximum of 4 threads per process
TOAST INFO: Running with 1 processes at 2020-10-08 09:35:26.808623
TOAST INFO: DRY RUN simulating 1024 total processes with 16 per node
TOAST INFO: Minimum detected per-node memory available is 57.53 GB
TOAST INFO: Setting per-node available memory to 90.00 GB as requested
TOAST INFO: Job has 64 total nodes
TOAST INFO: Examining 7 possible cases to run:
TOAST INFO:   tiny    : requires 1 nodes for 16 MPI ranks and 90.0GB per node
TOAST INFO:   xsmall  : requires 1 nodes for 16 MPI ranks and 90.0GB per node
TOAST INFO:   small   : requires 1 nodes for 16 MPI ranks and 90.0GB per node
TOAST INFO:   medium  : requires 5 nodes for 16 MPI ranks and 90.0GB per node
TOAST INFO:   large   : requires 47 nodes for 16 MPI ranks and 90.0GB per node
TOAST INFO:   xlarge  : requires 470 nodes for 16 MPI ranks and 90.0GB per node
TOAST INFO:   heroic  : requires 4700 nodes for 16 MPI ranks and 90.0GB per node
TOAST INFO: Selected case 'large'
TOAST INFO: Using groups of 1 nodes
TOAST INFO: Using 64 detectors for approximately 180 days
TOAST INFO: Generating input schedule file toast_001024_grp-0016p-01n_20201008-09:35:26/inputs/schedule.txt:
TOAST INFO: Adding patch "BICEP"
TOAST INFO: Rectangular format
TOAST INFO: Creating 'toast_001024_grp-0016p-01n_20201008-09:35:26/inputs'
TOAST INFO: Global timer: toast_ground_schedule:  35.72 seconds (1 calls)
TOAST INFO: Generating input map toast_001024_grp-0016p-01n_20201008-09:35:26/inputs/cmb.fits
TOAST INFO: Exit from dry run
```

You can see that for this configuration, the script would choose the "large" workflow
case.  The script actually goes through the process of creating an input sky signal map
for the simulation and also some number of days of telescope observing schedules.  These
are the same setup operations that would happen at the beginning of a real run.  You can
also see the different node counts needed for each of the possible workflow tests
assuming the same memory per node and processes per node that you specified.

### Starting Small

A good starting point is to begin with a single-node job.  Choose how many processes you
will be using per node.  Things to consider:

1.  Most of the parallelism in TOAST is process-level using MPI.  There is some limited use of OpenMP and there will soon be support for CUDA / OpenCL for some workflow modules.  However, running with more MPI ranks generally leads to better performance at the moment.

2.  There is some additional memory overhead on each node, so running nodes "fully packed" with MPI processes may not be possible.  You should experiment with different numbers of MPI ranks per node.

3.  Make sure to set `OMP_NUM_THREADS` appropriately so that the `(MPI ranks per node) X (OpenMP threads)` equals the total number of physical cores on each node.

Here is an example running interactively on `cori.nersc.gov`, which uses the SLURM
scheduler:

```bash
# 16 ranks per node, each with 4 threads.  
# 4 cores left for OS use.
# Depth is 16, due to 4 hyperthreads per core.
export OMP_NUM_THREADS=4
srun -C knl -q interactive -t 00:10:00 -N 1 -n 16 -c 16 \
toast_benchmark.py
```

### Scaling Up

After doing dry-run tests and running very small jobs you can increase the node count to
support something like the small / medium workflow cases.  At this point you can test
the effects of adjusting the number of MPI processes per node.  After you have found a
configuration that seems the best, increase the node count again to run the larger
cases.

### Metrics

At the end of the job a "Science Metric" is reported.  This is currently based on the
total number of data samples processed and the node-seconds that were used.  There is an
additional scale factor applied to reward the processing of larger data volumes, since
this enables more detailed treatment of correlations in the data.  The metric is
computed as:

```
Metric = (1.0e-6 * Total samples)^(Factor) / (Run seconds * Number of nodes)
```

Where the run time only includes the actual science calculations and not the
serial job setup portion.  From this equation, we can see that "large" nodes would be
preferred.  This Metric should be further divided by the "node watts" to obtain a
relative measure of "Science per Watt".

This benchmark script is testing a single TOAST workflow at different data volumes.
There are hundreds of possible workflows, but we have tried to capture the relevant
features in this one script.  For each TOAST release, there will be improvements to both
the software and there may also be changes to the benchmark script to attempt to make
the results more meaningful and realistic.

This raises a critical reminder:  any benchmark results should be accompanied by the
associated job log file, which includes information about the code version and
parameters that were used.  **Benchmarks should only be compared for the same TOAST
release**.

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
dependencies (including MPICH).  You should edit the `config-deps` and
`config-deps.pkgs` files to match your test system.

If you already have some dependencies installed and you are absolutely sure that
everything is ABI compatible, then you can comment out those package lines in the
`config-deps.pkgs` file.  After editing these files, install the dependencies to a
top-level prefix with:

```bash
./install_dependencies.sh /path/to/prefix
```

Then load this software stack before installing TOAST with:

```bash
source /path/to/prefix/cmbenv_init.sh
source cmbenv
```

Now install TOAST using the provided script.  This parses the same `config-deps` file
you made to get options which are passed to CMake:

```bash
./install_toast.sh
```

After this, you can always load the cmbenv environment above and all tools (including
TOAST) will be available.

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
