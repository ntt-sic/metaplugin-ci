#! /usr/bin/env bash

# Sets up a slave Jenkins server intended to run devstack-based Jenkins jobs

set -ex

THIS_DIR=`pwd`

DATA_PATH=$THIS_DIR/metaplugin-ci/data
PUPPET_MODULE_PATH="--modulepath=$THIS_DIR/metaplugin-ci/modules:$THIS_DIR/config/modules:/etc/puppet/modules"

### first step: copy THIS_DIR from master

### install puppet manually
### sudo bash config/install_puppet.sh
### TODO: puppet

### install puppet modules manually
### sudo bash config/install_modules.sh
### TODO: puppet

# Pulling in variables from data repository
. $DATA_PATH/vars.sh

###export UPSTREAM_GERRIT_SSH_PRIVATE_KEY_CONTENTS=`cat "$DATA_PATH/$UPSTREAM_GERRIT_SSH_KEY_PATH"`

# echo "Using Jenkins SSH key path: $DATA_PATH/$JENKINS_SSH_KEY_PATH"
###JENKINS_SSH_PRIVATE_KEY_CONTENTS=`sudo cat $DATA_PATH/$JENKINS_SSH_KEY_PATH`
#JENKINS_SSH_PUBLIC_KEY_CONTENTS=`sudo cat $DATA_PATH/$JENKINS_SSH_KEY_PATH.pub`

### must be key content only
### TODO: get by script
JENKINS_SSH_PUBLIC_KEY_CONTENTS='AAAAB3NzaC1yc2EAAAADAQABAAAAgQDIpnZwbQclrTLfTDt69eAq3Z1Hu/gmPlVX/WKdzMgBhHIIe8VnZKbFNv6AO6rvz6qeBP8hYwRXP+zCKDKggDhmZ+SfhtHrGXXOc76+NuoedV4taC7VN5HOA/UfZiZEwwtlaBAw+uZGj6z6yQ9ulTsK8Mh2Mne39Yk85NAqFLmW8Q=='

CLASS_ARGS="ssh_key => '$JENKINS_SSH_PUBLIC_KEY_CONTENTS', "
CLASS_ARGS="$CLASS_ARGS this_dir => '$THIS_DIR', "

sudo puppet apply --verbose $PUPPET_MODULE_PATH -e "class {'metaplugin_ci::slave': $CLASS_ARGS }"

### tmp comment out: do later manually
#if [[ ! -e /opt/git ]]; then
if [[ ! -e /opt/nodepool-scripts ]]; then
    sudo cp -a /etc/project-config/nodepool/scripts /opt/nodepool-scripts
    sudo mkdir -p /opt/git
    sudo -i python /opt/nodepool-scripts/cache_git_repos.py
    sudo /opt/nodepool-scripts/prepare_devstack.sh
fi
