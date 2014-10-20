#! /usr/bin/env bash

# Sets up a master Jenkins server and associated machinery like
# Zuul, JJB, Gearman, etc.

set -ex

LC_ALL=C
THIS_DIR=`pwd`

# To be sure here is paranet dir of metaplugin_ci
METAPLUGIN_CI=$THIS_DIR/metaplugin-ci
if [[ ! -d $METAPLUGIN_CI ]]; then
    echo "Expected to exist $METAPLUGIN_CI. Please correct. Exiting."
    exit 1
fi

# Pulling in variables from data repository
DATA_PATH=$THIS_DIR/data
if [[ ! -d $DATA_PATH ]]; then
    echo "Expected to exist $DATA_PATH. Please correct. Exiting."
    exit 1
fi
. $DATA_PATH/vars.sh

# Install Puppet and the OpenStack Infra Config source tree
CONFIG_DIR=/opt/config
CONFIG_REPO=${CONFIG_REPO:-https://github.com/openstack-infra/config}
if [[ ! -d $CONFIG_DIR ]]; then
    sudo git clone $CONFIG_REPO $CONFIG_DIR
    sudo bash -xe $CONFIG_DIR/install_puppet.sh
    sudo bash $CONFIG_DIR/install_modules.sh
fi

# Create a self-signed SSL certificate for use in Apache
APACHE_SSL_ROOT_DIR=$DATA_PATH/apache/ssl
if [[ ! -e $APACHE_SSL_ROOT_DIR/new.ssl.csr ]]; then
    echo "Creating self-signed SSL certificate for Apache"
    mkdir -p $APACHE_SSL_ROOT_DIR
    cd $APACHE_SSL_ROOT_DIR
    echo '
[ req ]
default_bits            = 2048
default_keyfile         = new.key.pem
default_md              = default
prompt                  = no
distinguished_name      = distinguished_name

[ distinguished_name ]
countryName             = US
stateOrProvinceName     = CA
localityName            = Sunnyvale
organizationName        = OpenStack
organizationalUnitName  = OpenStack
commonName              = localhost
emailAddress            = openstack@openstack.org
' > ssl_req.conf
    # Create the certificate signing request
    openssl req -new -config ssl_req.conf -nodes > new.ssl.csr
    # Generate the certificate from the CSR
    openssl rsa -in new.key.pem -out new.cert.key
    openssl x509 -in new.ssl.csr -out new.cert.cert -req -signkey new.cert.key -days 3650
    cd $THIS_DIR
fi
APACHE_SSL_CERT_FILE=`cat $APACHE_SSL_ROOT_DIR/new.cert.cert`
APACHE_SSL_KEY_FILE=`cat $APACHE_SSL_ROOT_DIR/new.cert.key`

UPSTREAM_GERRIT_SSH_PRIVATE_KEY_CONTENTS=`cat $DATA_PATH/gerrit_key`
JENKINS_SSH_PRIVATE_KEY_CONTENTS=`cat $DATA_PATH/jenkins_key`
JENKINS_SSH_PUBLIC_KEY_CONTENTS=`cat $DATA_PATH/jenkins_key.pub`

CLASS_ARGS="jenkins_ssh_public_key => '$JENKINS_SSH_PUBLIC_KEY_CONTENTS', "
CLASS_ARGS="$CLASS_ARGS jenkins_ssh_private_key => '$JENKINS_SSH_PRIVATE_KEY_CONTENTS', "
CLASS_ARGS="$CLASS_ARGS ssl_cert_file_contents => '$APACHE_SSL_CERT_FILE', "
CLASS_ARGS="$CLASS_ARGS ssl_key_file_contents => '$APACHE_SSL_KEY_FILE', "
CLASS_ARGS="$CLASS_ARGS upstream_gerrit_user => '$UPSTREAM_GERRIT_USER', "
CLASS_ARGS="$CLASS_ARGS upstream_gerrit_ssh_private_key => '$UPSTREAM_GERRIT_SSH_PRIVATE_KEY_CONTENTS', "
CLASS_ARGS="$CLASS_ARGS upstream_gerrit_host_pub_key => '$UPSTREAM_GERRIT_HOST_PUB_KEY', "
CLASS_ARGS="$CLASS_ARGS git_email => '$GIT_EMAIL', git_name => '$GIT_NAME', "
CLASS_ARGS="$CLASS_ARGS log_url_base => '$LOG_URL_BASE', "
CLASS_ARGS="$CLASS_ARGS log_server => '$LOG_SERVER', "
CLASS_ARGS="$CLASS_ARGS zuul_url => '$ZUUL_URL', "
CLASS_ARGS="$CLASS_ARGS jenkins_url => '$JENKINS_URL', "

PUPPET_MODULE_PATH="--modulepath=$METAPLUGIN_CI/modules:$CONFIG_DIR/modules:/etc/puppet/modules"
sudo puppet apply --debug --verbose $PUPPET_MODULE_PATH -e "class {'metaplugin_ci::master': $CLASS_ARGS }"
