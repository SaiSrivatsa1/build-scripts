#Testing Purpose
FROM registry.access.redhat.com/ubi9/ubi-minimal:latest

MAINTAINER "Srivatsa <Srighakollapu.Srivatsa1@ibm.com>"

ARG PACKAGE_VERSION=5.0.0

ENV SOURCE_DIR=/workspace
ENV PATH=/usr/local/bin:$PATH

# Install build dependencies (bcrypt has no s390x wheel, so pip compiles it from sdist using Rust)
RUN microdnf install -y git python3-devel python3-pip gcc gcc-c++ libffi-devel rust cargo \
    && microdnf clean all

# Clone the source and install bcrypt
RUN mkdir -p $SOURCE_DIR && cd $SOURCE_DIR \
    && git clone https://github.com/pyca/bcrypt.git \
    && cd bcrypt && git checkout $PACKAGE_VERSION \
    && pip3 install --no-cache-dir "setuptools-rust>=1.7.0" \
    && pip3 install --no-cache-dir .

USER 1001

CMD ["bash"]
