#!/bin/bash
# -----------------------------------------------------------------------------
#
# Package        : MariaDB Connector ODBC
# Version        : 3.2.6
# Source repo    : https://github.com/mariadb-corporation/mariadb-connector-odbc
# Tested on      : UBI:9.3
# Language       : c
# Ci-Check   : True
# Script License : Apache License, Version 2 or later
# Maintainer     : Yasir Ashfaq <Yasir.Ashfaq1@ibm.com>
#
# Disclaimer: This script has been tested in root mode on given
# ==========  platform using the mentioned version of the package.
#             It may not work as expected with newer versions of the
#             package and/or distribution. In such case, please
#             contact "Maintainer" of this script.
#
# ----------------------------------------------------------------------------
set -ex

# Variables
PACKAGE_NAME=MariaDB-Connector-ODBC
PACKAGE_VERSION=${1:-3.2.6}
SCRIPT_DIR=$(pwd)
PACKAGE_URL=https://github.com/MariaDB/mariadb-connector-odbc.git

# Install dependencies
yum install -y mariadb git cmake gcc gcc-c++ libarchive openssl-devel openssl tar wget libcurl-devel krb5-devel make glibc-langpack-en autoconf automake libtool
yum install -y yum-utils
yum-config-manager --add-repo http://rpmfind.net/linux/centos-stream/9-stream/AppStream/s390x/os/
yum-config-manager --add-repo http://rpmfind.net/linux/centos-stream/9-stream/BaseOS/s390x/os/
yum config-manager --set-enabled ubi-9-codeready-builder
yum config-manager --set-enabled ubi-9-codeready-builder-rpms
yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
# add repo for installing bison,flex
yum config-manager --add-repo https://mirror.stream.centos.org/9-stream/CRB/s390x/os
curl -o /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-Official http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-Official
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-Official
wget https://www.centos.org/keys/RPM-GPG-KEY-CentOS-Official
mv RPM-GPG-KEY-CentOS-Official /etc/pki/rpm-gpg/.
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-Official
yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
yum install mariadb-server mysql-devel libtool-ltdl-devel libiodbc-devel

#Install UnixODBC
cd $SCRIPT_DIR
git clone https://github.com/lurcher/unixODBC.git
cd unixODBC
git checkout 2.3.12
autoreconf -fi
./configure
make
make install
echo "UnixODBC installed successfully"

#Configure and Install mariadb-connector-odbc.git
cd $SCRIPT_DIR
git clone $PACKAGE_URL
cd mariadb-connector-odbc
git checkout $PACKAGE_VERSION
git submodule init
git submodule update
echo $DISTRO
cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCONC_WITH_UNIT_TESTS=Off  -DWITH_SSL=OPENSSL -DCMAKE_INSTALL_PREFIX=/usr/local -DODBC_LIB_DIR=/usr/local/lib
make
make install
cp /usr/local/lib/mariadb/libmaodbc.so /usr/local/lib
echo "MariaDB Connector ODBC installed successfully"

#Run Tests
mysql_install_db --user=mysql
sleep 20s
env PATH=$PATH mysqld_safe --user=mysql &
sleep 30s
ln -s /var/lib/mysql/mysql.sock /tmp/mysql.sock
env PATH=$PATH mysql -u root -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('');"
export TEST_DRIVER=maodbc_test
export TEST_SCHEMA=test
export TEST_DSN=maodbc_test
export TEST_UID=root
export TEST_PASSWORD=
cd $SCRIPT_DIR/mariadb-connector-odbc/test
export ODBCINI="$PWD/odbc.ini"
export ODBCSYSINI=$PWD
if ! ctest; then
    mysqladmin -u root --password="" shutdown
    echo "------------------$PACKAGE_NAME:Test_Fails---------------------"
    echo "$PACKAGE_URL $PACKAGE_NAME"
    echo "$PACKAGE_NAME  | $PACKAGE_VERSION | $OS_NAME | GitHub | Fail | Test_Fails"
	exit 1
else
    mysqladmin -u root --password="" shutdown
    echo "------------------$PACKAGE_NAME:Test_Success-------------------------"
    echo "$PACKAGE_VERSION $PACKAGE_NAME"
    echo "$PACKAGE_NAME  | $PACKAGE_VERSION | $OS_NAME | GitHub  | Pass | Test_Success"
fi
