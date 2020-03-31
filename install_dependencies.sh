#!/bin/bash
#
# This script uses the "cmbenv" tool to install dependencies
# for TOAST:
#
#     https://github.com/hpc4cmb/cmbenv
#
# See the README for more details.
#

usage () {
    echo "usage:  $0 <install prefix>"
    exit 1
}

# Install prefix
prefix=$1
if [ "x${prefix}" = "x" ]; then
    usage
fi

# Directory containing this script
pushd $(dirname $0) > /dev/null
scriptdir=$(pwd)
popd > /dev/null

# Runtime starting point
topdir=$(pwd)

# Clone the cmbenv package and build with our config.
if [ -d cmbenv ]; then
    # We already have a clone of cmbenv- just update to latest version
    cd cmbenv
    git checkout master
    git fetch
    git rebase origin/master
else
    git clone https://github.com/hpc4cmb/cmbenv.git
    cd cmbenv
fi
cp "${scriptdir}/config-deps" ./config/bench
cp "${scriptdir}/config-deps.pkgs" ./config/bench.pkgs
./cmbenv -c bench -p "${prefix}"
mkdir -p build
cd build
../install_bench.sh | tee log
cd "${topdir}"

# Print a reminder
echo "To load this software stack, do:"
echo "  source ${prefix}/cmbenv_init.sh"
echo "  source cmbenv"
