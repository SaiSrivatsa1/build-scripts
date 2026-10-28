#!/bin/bash -e
# -----------------------------------------------------------------------------
# Package       : yarl
# Version       : v1.24.2
# Source repo   : https://github.com/aio-libs/yarl
# Tested on     : UBI:9.3
# Language      : Python
# Script License: Apache License, Version 2 or later
# Maintainer    : Srighakollapu-Srivatsa1 <Srighakollapu.Srivatsa1@ibm.com>
#
# Disclaimer    : This script has been tested in root mode on given
# ==========      platform using the mentioned version of the package.
#                 It may not work as expected with newer versions of the
#                 package and/or distribution. In such case, please
#                 contact "Maintainer" of this script.
#
# Notes:
#   - yarl is a Cython-based URL parsing library from aio-libs
#   - Cython extensions are compiled during the build process
#   - Container environment provides: gcc/g++, python
#   - Repository is pre-cloned with full history for version flexibility
# -----------------------------------------------------------------------------

# Get script directory for template sourcing
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =============================================================================
# REQUIRED: Package metadata
# =============================================================================
PACKAGE_NAME="yarl"
PACKAGE_VERSION="${1:-v1.24.2}"
PACKAGE_URL="https://github.com/aio-libs/yarl"

# =============================================================================
# REQUIRED: Dependencies
# System packages needed for building yarl
# Note: gcc/g++ are provided by the container
# =============================================================================
RH_DEP_PKGS="git openssl-devel bzip2-devel libffi-devel zlib-devel python3-devel python3-pip"
DEB_DEP_PKGS="git libssl-dev libbz2-dev libffi-dev zlib1g-dev python3-dev python3-pip python3-venv"
SLES_DEP_PKGS="git libopenssl-devel libbz2-devel libffi-devel zlib-devel python3-devel python3-pip"
NOARCH="true"
# =============================================================================
# CALLBACK: pre_build
# Install cython and generate .c files before python -m build runs
# Note: This runs INSIDE .venv-build, so pip install works correctly
# =============================================================================
#pre_build() {
#   log_info "Installing deps"
##    # Install build backend to support --no-isolation                                                                                                                          │
#   log_info "Installing build backend dependencies..."                                                                                                                        │
#    pip install cython "setuptools>=82.0.1" wheel expandvars tomli

#    log_info "Running cython to generate C extensions..."
#    # yarl uses -I yarl for include path as specified in Makefile
#    for pyx_file in yarl/*.pyx; do
#        if [[ -f "$pyx_file" ]]; then
#            log_info "Cythonizing ${pyx_file}..."
#            if ! python${PYTHON_VERSION} -m cython -3 -o "${pyx_file%.pyx}.c" "$pyx_file" -I yarl; then
#                log_error "Failed to cythonize ${pyx_file}"
##                return 1
#           fi
#        fi
#    done
#    log_info "Generated .c files: $(ls yarl/*.c 2>/dev/null || echo 'none')"
#}

# =============================================================================
# CALLBACK: custom_test_command
# Run tests with proper configuration
# =============================================================================
custom_test_command() {
    log_info "Installing test dependencies..."

    # Install test requirements
    if [[ -f "requirements/test.txt" ]]; then
        pip install -r requirements/test.txt || true
    fi

    # Install additional test dependencies (hypothesis for property-based testing)
    pip install hypothesis || true

    # Ensure we have a working pytest (requirements may pin old versions)
    pip install --upgrade "pytest>=7.0" || true

    # Remove plugins that crash during entrypoint loading (before -p no: is processed)
    # These have version conflicts with modern pytest that cause import-time failures
    pip uninstall -y pytest-cov pytest-xdist pytest-codspeed 2>/dev/null || true

    log_info "Running pytest..."

    # Override setup.cfg/pyproject.toml addopts which may include --cov (requires pytest-cov)
    pytest \
        -o "addopts=" \
        --disable-warnings
}

# =============================================================================
# Source the Python template to execute the build workflow
# =============================================================================
source "${SCRIPT_DIR}/../../v2-templates/python.sh"
