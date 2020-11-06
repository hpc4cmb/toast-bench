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
%>  toast_benchmark.py --help

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
%>  toast_benchmark.py --node_mem_gb 90 --dry_run 1024,16

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
%>  export OMP_NUM_THREADS=4
%>  srun -C knl -q interactive -t 00:10:00 -N 1 -n 16 -c 16 \
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
number of detectors, total number of data samples processed and the node-seconds that
were used.  The different exponents in the metric attempt to weight different aspects of
the job in an appropriate way.  For example, often it is critical to process a group of
hundreds to several thousands of detectors together in a single job.  The more observing
time we can process in a single job also leads to better quality results.  The metric is
currently computed as:

```
Metric = (constant prefactor) x (Number of detectors)^2 x (1.0e-3 * Total samples)^1.2
            / (Run seconds * Number of nodes)
```

Where the run time only includes the actual science calculations and not the
serial job setup portion.  From this equation, we can see that "large" nodes would be
preferred.  This Metric should be further divided by the "node watts" to obtain a
relative measure of "Science per Watt".

This benchmark script is testing a single TOAST workflow at different data volumes.
There are hundreds of possible workflows, but we have tried to capture the relevant
features in this one script.  For each TOAST release, there will be improvements to the
software and there may also be changes to the benchmark script to make the results more
meaningful and realistic.

This raises a critical reminder:  any benchmark results should be accompanied by the
associated job log file, which includes information about the code version and
parameters that were used.  **Benchmarks should only be compared for the same TOAST
release**.

## Installation

There are several ways to install TOAST.  Pre-built binary packages are available as pip
wheels and also through the conda-forge channel.  When running benchmarks on a new or
unusual system, you may achieve better performance building TOAST and some or all of the
dependencies from scratch.  However, it can be useful to run the tests with pre-built
packages as a starting point for the performance testing and as a point of comparison.

### Installing Pre-built Binaries

A full discussion of TOAST installation [is in the official
documentation](https://toast-cmb.readthedocs.io/en/latest/install.html).  Here we
provide a summary.  Make sure that you have a Python3 installation that is at least
version 3.6.0:

```bash
%>  python3 --version
Python 3.8.2
```

#### Using Pip

For installation of packages from PyPI (the most general method), first create a new
"virtualenv" that will act as a sandbox environment for our installation.  You can call
this whatever you like, but for this example we will make a location called `toast` in
our home directory:

```bash
%>  python3 -m venv ${HOME}/toast
```

Now activate this environment:

```bash
%>  source ${HOME}/toast/bin/activate
```

Within this virtualenv, update pip to the latest version.  This is needed in order to
install more recent wheels from PyPI:

```bash
%>  python3 -m pip install --upgrade pip
```

Next, use pip to install toast and its requirements (note that the name of the package
is "toast-cmb" on PyPI):

```bash
%>  python3 -m pip install toast-cmb
```

Although TOAST does not require MPI, it is needed for any meaningful benchmarking work.
We will install the `mpi4py` package, but first need to make sure that we have a working
MPI C compiler.  You can [read about install options for mpi4py
here](https://mpi4py.readthedocs.io/en/stable/install.html).  For example, if your MPI
compiler wrapper is called "`cc`", then you would do:

```bash
# (Substitute the name of your MPI C compiler)
%>  MPICC=cc python3 -m pip install --no-cache-dir mpi4py
```

It is always a good idea to run the TOAST unit tests with your new installation:

```bash
# Example:  generic Linux:
%>  export OMP_NUM_THREADS=1
%>  mpirun -np 4 python3 -c 'import toast.tests; toast.tests.run()'

# Example:  on cori.nersc.gov with slurm:
%>  export OMP_NUM_THREADS=4
%>  srun -N 1 -n 4 -C haswell -t 00:30:00 python3 -c 'import toast.tests; toast.tests.run()'
```

#### Using Conda

If you are already using the `conda` python package manager, then you may find it easier
to install TOAST from the packages in the `conda-forge` package repository.  Before
doing any conda operations (like creating an environment), you must make sure that conda
has been initialized with the `conda init` command or by manually sourcing the shell
snippet to do this.  **Simply having the `conda` command in your search path is not
sufficient**.  For example, on the cori system at NERSC you would do:

```bash
# Load conda command into your path:
module load python

# Actually initialize conda:
conda init
```

The `init` command adds a shell snippet to your `~/.bashrc`.  Now reload your shell
resource file or log out and log back in.  Now we are ready to use the conda tool.

> **NOTE**:  If you don't want to always load the conda software stack in your
~/.bashrc, then you can create your own shell function which does the same thing.  For example, at NERSC, you could add this function to ~/.bashrc:

```bash
load_conda () {
    module load python
    conda_prefix=$(dirname $(dirname $(which conda)))
    source "${conda_prefix}/etc/profile.d/conda.sh"
}
```

Then from a fresh shell you can selectively do:

```bash
%>  load_conda
```

Only when you want to use this conda installation.  Now that our conda tool is
initialized, we can install TOAST.  Begin by creating a new conda environment:

```bash
%>  conda create -y -n toast
```

Now activate this environment and install TOAST:

```bash
%>  conda activate toast
%>  conda install -y -c conda-forge toast
```

The conda tool currently installs a replacement linker (`ld` program) which frequently breaks compilation on some systems.  We are going to remove it from our environment, so that we can successfully compile `mpi4py` in the next step:

```bash
%>  rm -f $(dirname $(dirname $(which python)))/compiler_compat/ld
```

For meaningful benchmarking, we need to install `mpi4py`.

> **NOTE**:  On HPC systems, you should install mpi4py with pip, *not* conda.  This
> will allow compilation of mpi4py against the system compilers.

```bash
# On a laptop or workstation:
%>  conda install mpi4py

# On an HPC system with a vendor MPI installation:
# (Substitute the name of your MPI C compiler)
%>  MPICC=cc python3 -m pip install --no-cache-dir mpi4py
```

It is always a good idea to run the TOAST unit tests with your new installation:

```bash
# Example:  generic Linux:
%>  export OMP_NUM_THREADS=1
%>  mpirun -np 4 python3 -c 'import toast.tests; toast.tests.run()'

# Example:  on cori.nersc.gov with slurm:
%>  export OMP_NUM_THREADS=4
%>  srun -N 1 -n 4 -C haswell -t 00:30:00 python3 -c 'import toast.tests; toast.tests.run()'
```

### Installing from Source

Before trying to build TOAST from source for running these benchmarks, you should first
make sure that you have installed all dependencies needed for the benchmark workflow.
There are other optional dependencies for TOAST, but they are not required for the
benchmark:

* A C++11 compiler
* A BLAS / LAPACK installation
* [FFTW](http://fftw.org/) libraries
* [CMake](https://cmake.org/) (>= 3.12)
* [SuiteSparse](http://faculty.cse.tamu.edu/davis/suitesparse.html) (for atmosphere simulations)
* [libaatm](https://github.com/hpc4cmb/libaatm) (for atmosphere simulations)
* Python3 (>= 3.6)
* Python packages:  numpy, scipy, astropy, healpy, h5py, ephem
* MPI and mpi4py (for effective parallelism)

See the next section for how to use some of the scripts included in this repository to
install all these dependencies.

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


#### Dependencies:  Installing from Scratch

If you just want to "override" specific dependencies with manually installed versions,
you can comment out the package in the `config-deps.pkgs` file and use the cmbenv tools
mentioned above.

There may be cases where you want to install everything manually.  In this case, you
should ensure the following:

- Your math libraries (LAPACK, FFTW, and SuiteSparse) are binary compatible with each other and with your serial compilers.

- Your Python3 installation is recent.  Versions 3.6-3.8 are regularly tested by our continuous integration workflows.  If you are using a system Python3, create a virtualenv for these benchmarks and activate it.  If you are using a conda-based Python3 stack, create a new conda environment for these benchmarks and activate it.

- Some python packages ship with pre-built shared libraries.  When you install these packages with pip or conda, these libraries will be placed in your virtualenv or conda environment.  You must ensure that the directory containing these libraries is **not** in the search path used by the linker (e.g. LD_LIBRARY_PATH).  Often these libraries are incompatible with other system libraries and should only be loaded by the python packages using them.

- When installing compiled dependencies, these libraries need to be visible to the linker when linking the internal TOAST library.  Since these libraries need to be in the linker search path, you should **not** install them directly to the virtualenv or conda environment prefix you are using for python packages.  Install compiled dependencies to another location which you can then put into PATH, LD_LIBRARY_PATH, and PYTHONPATH.

> **WARNING**: conda installs its own version of a linker.  If you are using a conda
> environment, check if the file `compiler_compat/ld` exists in the conda environment
> prefix.  If so, remove it or rename it.

Here is an overview of the steps for manually setting up a TOAST test environment.
Since there will be several locations of installed software, I recommend creating a
shell function / alias which adds everything to PATH, LD_LIBRARY_PATH, etc:

1.  Select your serial compilers and any pre-existing versions of BLAS / LAPACK, FFTW, and SuiteSparse that you would like to use.  Ensure that these are loaded in your shell environment.

2.  If using MPI, ensure that your MPI installation is loaded in your shell environment.

3.  Determine what Python3 you will be using.  If you are using a system Python3, create a virtualenv for these benchmarks and activate it.  If you are using a conda-based Python3 stack, create a new conda environment for these benchmarks and activate it.  See note above, and delete `compiler_compat/ld` if it exists in the conda environment.

4.  Install the following python packages: `numpy`, `scipy`, `matplotlib`, `healpy`, `astropy`, `pysm3`, `h5py`, `ephem`, `cmake`.  If you are working with a virtualenv, install these packages with pip.  If using a conda environment, install these with conda.

5.  Install the `mpi4py` package with pip (not conda).  Read the documentation of that package to see how to make sure it finds your intended MPI compiler.

6.  Determine where you wish to install any manually compiled dependencies (and TOAST).  Install compiled dependencies you do not already have:  [FFTW](http://fftw.org/), [SuiteSparse](http://faculty.cse.tamu.edu/davis/suitesparse.html), [libaatm](https://github.com/hpc4cmb/libaatm).

Now we are ready to install TOAST to the location where we are placing our compiled
packages and things outside of our virtualenv / conda env.  Assuming you installed the
compiled packages in step (6) above to `/path/to/toast`, you need to export that install
prefix into your environment:

```bash
%>  export PATH=/path/to/toast/bin:${PATH}
%>  export CPATH=/path/to/toast/include:${CPATH}
%>  export LD_LIBRARY_PATH=/path/to/toast/lib:${LD_LIBRARY_PATH}
%>  export PYTHONPATH=/path/to/toast/lib/python3.x/site-packages:${PYTHONPATH}
```

Next go into the TOAST source tree and make a build directory:

```bash
mkdir build
cd build
```

Now run cmake from here.  For this example, we'll continue to use the hypothetical
install prefix `/path/to/toast`.  Also assume we installed FFTW, libaatm, and
SuiteSparse to this location.  Pretend we wanted to install TOAST on a Cray system at
NERSC using the Intel compilers and building object code optimized for both the login
nodes and the KNL compute nodes.  We could do this:

```bash
PREFIX=/path/to/toast cmake \
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

To use this TOAST install for benchmarking, you would first activate your virtualenv or
conda environment, and then export your install prefix into your environment.  Running
the unit tests are a good way to test the TOAST installation.
