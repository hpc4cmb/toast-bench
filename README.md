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
%>  srun -C knl -q interactive -t 00:30:00 -N 1 -n 16 -c 16 \
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

The conda tool currently installs a replacement linker (`ld` program) which frequently
breaks compilation on some systems.  We are going to remove it from our environment, so
that we can successfully compile `mpi4py` in the next step:

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

This git repo includes some scripts to install the minimum dependencies needed by TOAST
for the benchmarks.  However, there are some external requirements that must already
exist on the system:

* A C++11 compiler
* [CMake](https://cmake.org/) (>= 3.12)
* Python3 (>= 3.6)
* Python packages:  numpy, scipy, h5py
* MPI and mpi4py (for effective parallelism)

Before installing the remaining dependencies, you should make sure the above tools are
loaded into your environment.

> **WARNING**: conda installs its own version of a linker.  If you are using a conda
> environment for your Python, check if the file `compiler_compat/ld` exists in the
> conda environment prefix.  If so, remove it or rename it.

If you are using a conda environment, make sure to install the `mpi4py` package with pip
(not conda).  Read the documentation of that package to see how to make sure it finds
your intended MPI compiler.

#### Installing Dependencies

The remaining minimal dependencies can be installed with the included `install_deps.sh`
script.  The defaults in this script use the GNU compilers, but there are comments in
the script about where to make changes for other use cases.  You can comment out the
installation of some packages completely if you already have an optimized replacement
installed.  There are also several examples (`example_deps_*.sh`) included.  The script
supports installing:

* OpenBLAS (not needed if using an alternate BLAS/LAPACK)
* [FFTW](http://fftw.org/) (not needed if using Intel MKL)
* [SuiteSparse](http://faculty.cse.tamu.edu/davis/suitesparse.html) (for atmosphere simulations)
* [libaatm](https://github.com/hpc4cmb/libaatm) (for atmosphere simulations)
* Python packages:  astropy, healpy, ephem

After modifying this script to your needs, just run it:
```bash
%>  ./install_deps.sh
```

After installing the dependencies, this script prints out an example shell function
(`load_toast`) which can be added to your `~/.bashrc` for easy loading of this software
stack.

#### Installing TOAST

After loading the software stack you installed in the previous section, we can install
TOAST to this same location.  The included `install_toast.sh` script is an example that
sets up the compilers and dependency locations, checks out a version of TOAST from
github, and installs it to the same location as the compiled dependencies.  There are
some examples (`example_toast_*.sh`) as well.  After modifying, run this script:
```bash
%>  ./install_toast.sh
```

After installation, it is a good idea to run the unit test suite (see previous
sections).

#### Warnings and Caveats

The compiled python extension in TOAST links to external libraries for BLAS/LAPACK and
FFTs.  The python Numpy package may use some of the same libraries for its internal
operations.  Inside a single process, a shared library can only be loaded once.  For
example, if numpy links to `libmkl_rt` and so does TOAST, then only one copy of
`libmkl_rt` can be loaded- and the library which actually gets loaded depends on the
order of importing the `toast` and `numpy` python modules!

For example, here are some combinations and the result:

TOAST Built With | Python Using | Result
-----------------|--------------|---------
Statically linked OpenBLAS (binary wheels on PyPI) | numpy with any LAPACK | **Works** since TOAST does not load any external LAPACK.
Intel compiler and MKL | numpy with MKL | Broken, **UNLESS** both MKLs are ABI compatible and using the Intel threading layer.
GCC compiler and MKL | numpy with MKL | Broken, since TOAST uses the MKL GNU threading layer and numpy uses the Intel threading layer (only one can be used in a single process).
GCC and system OpenBLAS | numpy with MKL | **Works**: different libraries are dl-opened by TOAST and numpy.
Intel compiler and MKL | numpy with OpenBLAS (from conda-forge) | **Works**: different libraries are dl-opened by TOAST and numpy.

When in doubt, run the toast unit tests with OpenMP enabled (i.e. `OMP_NUM_THREADS` >
1).  This should exercise code that will fail if there is some incompatibility. After
the unit tests pass, you are ready to run the benchmarks.
