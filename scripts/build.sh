#!/bin/env dash

# Description: Automate building the ISO
# Version: v1.1

# Safer script
set -o errexit
set -o nounset
trap "exit" INT

# Variables
parent=$(pwd)

# Cleanup
cleanup () {
    rm -fr "$parent"/archiso-base "$parent"/work "$parent"/out
}

# Fetch and patch files
setup () {
    git clone git@github.com:ChangqingW/archiso.git --branch custom --depth=1 archiso-base
}

# Setup local repo
repo () {
    cd "$parent"
    "$parent"/scripts/local_repo.sh
}

# Build the ISO
build () {
    cd "$parent"/archiso-base # to fix errors while creating temporary files
    mkarchiso -v configs/releng
}

# Actually do stuffs
if [ "$(id -u)" -eq 0 ] # require root
then 
        cleanup
        setup
        build
else printf '%s\n' 'Root priveleges are required!'
fi
