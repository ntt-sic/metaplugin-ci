#! /usr/bin/env bash

# Sets up a master Jenkins server and associated machinery like
# Zuul, JJB, Gearman, etc.

set -ex

### asume ci-test top
THIS_DIR=`pwd`

DATA_PATH=$THIS_DIR/data
PUPPET_MODULE_PATH="--modulepath=$THIS_DIR/metaplugin-ci/modules:$THIS_DIR/config/modules:/etc/puppet/modules"

### manually git clone openstack-infra/config to THIS_DIR
### git clone https://github.com/openstack-infra/config
### TODO: fix commit id

### install puppet manually
### sudo bash config/install_puppet.sh
### TODO: puppet

### install puppet modules manually
### sudo bash config/install_modules.sh
### TODO: puppet

# Pulling in variables from data repository
### TODO: define direct
. $DATA_PATH/vars.sh

export UPSTREAM_GERRIT_SSH_PRIVATE_KEY_CONTENTS=`cat "$DATA_PATH/$UPSTREAM_GERRIT_SSH_KEY_PATH"`

# Validate there is a Jenkins SSH key pair in the data repository
echo "Using Jenkins SSH key path: $DATA_PATH/$JENKINS_SSH_KEY_PATH"
JENKINS_SSH_PRIVATE_KEY_CONTENTS=`sudo cat $DATA_PATH/$JENKINS_SSH_KEY_PATH`
JENKINS_SSH_PUBLIC_KEY_CONTENTS=`sudo cat $DATA_PATH/$JENKINS_SSH_KEY_PATH.pub`

PUBLISH_HOST=${PUBLISH_HOST:-localhost}

# Create a self-signed SSL certificate for use in Apache
APACHE_SSL_ROOT_DIR=$THIS_DIR/tmp/apache/ssl
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

CLASS_ARGS="jenkins_ssh_public_key => '$JENKINS_SSH_PUBLIC_KEY_CONTENTS', "
CLASS_ARGS="$CLASS_ARGS jenkins_ssh_private_key => '$JENKINS_SSH_PRIVATE_KEY_CONTENTS', "
CLASS_ARGS="$CLASS_ARGS ssl_cert_file_contents => '$APACHE_SSL_CERT_FILE', "
CLASS_ARGS="$CLASS_ARGS ssl_key_file_contents => '$APACHE_SSL_KEY_FILE', "
CLASS_ARGS="$CLASS_ARGS upstream_gerrit_user => '$UPSTREAM_GERRIT_USER', "
CLASS_ARGS="$CLASS_ARGS upstream_gerrit_ssh_private_key => '$UPSTREAM_GERRIT_SSH_PRIVATE_KEY_CONTENTS', "
CLASS_ARGS="$CLASS_ARGS upstream_gerrit_host_pub_key => '$UPSTREAM_GERRIT_HOST_PUB_KEY', "
CLASS_ARGS="$CLASS_ARGS git_email => '$GIT_EMAIL', git_name => '$GIT_NAME', "
CLASS_ARGS="$CLASS_ARGS publish_host => '$PUBLISH_HOST', "
CLASS_ARGS="$CLASS_ARGS zuul_url => '$ZUUL_URL', "
CLASS_ARGS="$CLASS_ARGS jenkins_url => '$JENKINS_URL', "

# Doing this here because ran into one problem after another trying
# to do this in Puppet... which won't let me execute Ruby code in
# a manifest and doesn't allow you to "merge" the contents of two
# directory sources in the file resource. :(
#sudo mkdir -p /etc/jenkins_jobs/config
#sudo cp -r $DATA_PATH/etc/jenkins_jobs/config/* /etc/jenkins_jobs/config/

sudo puppet apply --debug --verbose $PUPPET_MODULE_PATH -e "class {'metaplugin_ci::master': $CLASS_ARGS }"
