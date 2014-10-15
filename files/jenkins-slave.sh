#!/bin/bash

JENKINS_URL=${JENKINS_URL:-http://master:8080/}
JENKINS_NODENAME=${JENKINS_NODENAME:-$(hostname)}
JENKINS_CLI=/opt/metaplugin-ci/files/jenkins-cli.jar

jenkins_cli() {
        cmd=$1
        sudo -u jenkins java -jar $JENKINS_CLI -s $JENKINS_URL $cmd $JENKINS_NODENAME
}

case "$1" in
online)
        jenkins_cli online-node
        jenkins_cli connect-node
        ;;
offline)
        jenkins_cli offline-node
        ;;
*)
        echo "$(basename $0) [online|offline]"
        ;;
esac
