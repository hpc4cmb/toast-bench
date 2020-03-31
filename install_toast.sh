#!/bin/bash
#
# This script installs TOAST using the cmbenv dependency stack
#
# See the README for more details.
#

# Verify that we have the cmbenv stack loaded

if [ "x${CMBENV_ROOT}" = "x" ]; then
    echo "You should load the cmbenv stack before running this script"
    exit 1
fi

usage () {
    echo "usage:  $0 [tag or git hash]"
    exit 1
}

# TOAST version to install
version=$1
if [ "x${version}" = "x" ]; then
    version="master"
fi

# Directory containing this script
pushd $(dirname $0) > /dev/null
scriptdir=$(pwd)
popd > /dev/null

# Runtime starting point
topdir=$(pwd)

# Clone TOAST and checkout desired version
if [ -d toast ]; then
    # We already have a clone of toast, just update
    cd toast
    git checkout master
    git fetch
    git rebase origin/master
else
    git clone https://github.com/hpc4cmb/toast.git
    cd toast
fi
git checkout -B bench ${version}

# Parse the config file parameters

confsub="-e 's#@TOAST_VERSION@#${version}#g'"

while IFS='' read -r line || [[ -n "${line}" ]]; do
    # is this line commented?
    comment=$(echo "${line}" | cut -c 1)
    if [ "${comment}" != "#" ]; then
        check=$(echo "${line}" | sed -e "s#.*=.*#=#")
        if [ "x${check}" = "x=" ]; then
            # get the variable and its value
            var=$(echo ${line} | sed -e "s#\([^=]*\)=.*#\1#" | awk '{print $1}')
            val=$(echo ${line} | sed -e "s#[^=]*= *\(.*\)#\1#")
            if [ "${var}" = "PYVERSION" ]; then
                if [ "x${val}" = "xauto" ]; then
                    val=$(python3 --version 2>&1 | awk '{print $2}' | sed -e "s#\(.*\)\.\(.*\)\..*#\1.\2#")
                fi
                pyversion="${val}"
            fi
            # add to list of substitutions
            confsub="${confsub} -e 's#@${var}@#${val}#g'"
        fi
    fi
done < "${scriptdir}/config-deps"

# Create CMake config script
conf="config.sh"
rm -f "${conf}"
while IFS='' read -r line || [[ -n "${line}" ]]; do
    echo "${line}" | eval sed ${confsub} >> "${conf}"
done < "${scriptdir}/toast_config_template.sh"
chmod +x "${conf}"

# Build and install
mkdir -p build
cd build
../${conf}
make -j 4 install

# Back to the start
cd "${topdir}"
