#!/bin/bash

IS_REDHAT=$(cat /etc/os-release | egrep '^ID' | grep rhel)
if [[ -n ${IS_REDHAT} ]]
then
    yum install -y nc
    yum install -y netcat
fi

echo "Done"