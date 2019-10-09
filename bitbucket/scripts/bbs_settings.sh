#!/usr/bin/env bash

BBS_USER="atlbitbucket"
BBS_GROUP="atlbitbucket"
BBS_UID="9079"
BBS_GID="9079"
BBS_HOME="${ATL_HOME}/bitbucket"
BBS_SHARED_HOME="${BBS_HOME}/shared"

BBS_SHARED_HOME_MOUNT_OPTS="lookupcache=pos,noatime,intr,rsize=32768,wsize=32768,vers=3"

BBS_INSTALLER_VARS="installer.varfile"
BBS_INSTALL_DIR="/opt/atlassian/bitbucket/${BBS_VERSION}"