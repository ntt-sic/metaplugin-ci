#! /usr/bin/env bash

# Sets up a slave Jenkins server intended to run devstack-based Jenkins jobs

set -ex

THIS_DIR=`pwd`
DATA_PATH=$THIS_DIR/data
METAPLUGIN_CI=$THIS_DIR/metaplugin-ci
CONFIG_DIR=/opt/config

# To be sure here is paranet dir of metaplugin_ci
if [[ ! -d $METAPLUGIN_CI ]]; then
    echo "Expected to exist $METAPLUGIN_CI. Please correct. Exiting."
    exit 1
fi

# Pulling in variables from data repository
. $DATA_PATH/vars.sh

# Install Puppet and the OpenStack Infra Config source tree
CONFIG_REPO=${CONFIG_REPO:-https://github.com/openstack-infra/config}
if [[ ! -d $CONFIG_DIR ]]; then
    sudo git clone $CONFIG_REPO $CONFIG_DIR
    sudo bash -xe $CONFIG_DIR/install_puppet.sh
    sudo bash $CONFIG_DIR/install_modules.sh
fi

# NOTE: must be key content only
JENKINS_SSH_PUBLIC_KEY_CONTENTS=`cat $DATA_PATH/jenkins_key.pub | awk '{print $2}'`

CLASS_ARGS="ssh_key => '$JENKINS_SSH_PUBLIC_KEY_CONTENTS', "
CLASS_ARGS="$CLASS_ARGS this_dir => '$THIS_DIR', "

PUPPET_MODULE_PATH="--modulepath=$METAPLUGIN_CI/modules:$CONFIG_DIR/modules:/etc/puppet/modules"
sudo puppet apply --verbose $PUPPET_MODULE_PATH -e "class {'metaplugin_ci::slave': $CLASS_ARGS }"

if [[ ! -e /opt/nodepool-scripts ]]; then
    sudo cp -a /etc/project-config/nodepool/scripts /opt/nodepool-scripts
    sudo mkdir -p /opt/git
    sudo -i python /opt/nodepool-scripts/cache_git_repos.py
    sudo /opt/nodepool-scripts/prepare_devstack.sh
fi
