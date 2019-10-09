#!/usr/bin/env bash

source ./log.sh
source ./settings.sh

function ensure_atlhome {
    log "Making sure Atlassian home directory exists"
    mkdir -p "${ATL_HOME}"
    log "Atlassian home has been created"
}

function ensure_prerequisites {
    
    IS_REDHAT=$(cat /etc/os-release | egrep '^ID' | grep rhel)
    install_pacapt
    install_redhat_epel_if_needed
    install_core_dependencies

    ensure_atlhome
}

function create_bb_group {
    log "Preparing a group for Bitbucket Server"

    # Options:
    #  hardcoded group id - neds to be the same on NFS server and client
    #  group name
    groupadd -fg "${BBS_GID}" "${BBS_GROUP}"

    log "Bitbucket Server group has been created"
}

function create_bb_user {
    log "Preparing a user for Bitbucket Server"

    # Options:
    #  create home directory as specified
    #  no login shell
    #  hardcoded user id - needs to be the same on NFS server and client
    #  same goes for group id
    #  a comment for the user
    #  username
    id -u ${BBS_USER} >/dev/null 2>&1 || useradd -m -d "${BBS_HOME}" \
        -s /bin/bash \
        -u "${BBS_UID}" \
        -g "${BBS_GID}" \
        -c "Atlassian Bitbucket" \
        "${BBS_USER}" 

    log "Bitbucket Server user has been created"
}

function create_bb_owner {
    log "Creating Bitbucket Server owner"

    create_bb_group
    create_bb_user

    log "Bitbucket Server owner is ready"
}


function prepare_datadisks {
  log "Preparing data disks, striping, adding to fstab"
  ./vm-disk-utils-0.1.sh -b "/datadisks" -o "noatime,nodiratime,nodev,noexec,nosuid,nofail,barrier=0" -s
  log "Done preparing and configuring data disks"
}

function nfs_install_server {
    log "Installing NFS server..."
    pacapt install --noconfirm nfs-kernel-server
    log "NFS server has been installed"
}

function nfs_update_fstab {
    log "Updating fstab to bind [directory=${NFS_DISK_MOUNT}] to [directory=${NFS_SHARED_HOME}] at boot time."

    printf "\n${NFS_DISK_MOUNT}\t${NFS_SHARED_HOME}\tnone\tdefaults,bind\t0 0\n" >> /etc/fstab

    log "fstab has been updated"
}

function nfs_bind_directory {
    log "Binding [directory=${NFS_DISK_MOUNT}] to [directory=${NFS_SHARED_HOME}]"

    mount -B "${NFS_DISK_MOUNT}" "${NFS_SHARED_HOME}"

    log "Bound [directory=${NFS_DISK_MOUNT}] to [directory=${NFS_SHARED_HOME}]"
}

function nfs_create_installer_dir {
    log "Creating NFS installer directory:${NFS_INSTALLER_DIR}"

    mkdir -p "${NFS_INSTALLER_DIR}"

    log "Done creating NFS installer directory:${NFS_INSTALLER_DIR}!"
}

function nfs_create_shared_home {
    log "Creating NFS shard home [directory=${NFS_SHARED_HOME}]"

    mkdir -p "${NFS_SHARED_HOME}"

    log "Done creating NFS shared home  [directory=${NFS_SHARED_HOME}]!"
}

function nfs_prepare_installer_dir {
    log "Preparing installer directory"

    nfs_create_installer_dir

    log "Updating [owner=${BBS_USER}":"${BBS_GROUP}] for [directory=${NFS_INSTALLER_DIR}]"
    chown "${BBS_USER}":"${BBS_GROUP}" "${NFS_INSTALLER_DIR}"

    log "Installer directory is ready!"

    bbs_download_installer
}

function nfs_prepare_shared_home {
    log "Preparing shared home directory"

    nfs_create_shared_home
    nfs_bind_directory

    log "Updating [owner=${BBS_USER}":"${BBS_GROUP}] for [directory=${NFS_SHARED_HOME}]"
    chown "${BBS_USER}":"${BBS_GROUP}" "${NFS_SHARED_HOME}"

    nfs_update_fstab

    log "Shared home directory is ready!"
}

function nfs_configure_ports {
    log "Setting statd port"
    printf "\nSTATDOPTS=\"--port 32765 --outgoing-port 32766\"\n" >> /etc/default/nfs-common

    log "Setting mountd port"
    printf "\nRPCMOUNTDOPTS=\"-p 32767\"\n" >> /etc/default/nfs-kernel-server

    log "Setting quotad port"
    printf "\nRPCRQUOTADOPTS=\"-p 32769\"\n" >> /etc/default/quota

    log "Setting lockd port"
    printf "\nfs.nfs.nfs_callback_tcpport = 32764\n" >> /etc/sysctl.d/nfs-static-ports.conf
    printf "fs.nfs.nlm_tcpport = 32768\n" >> /etc/sysctl.d/nfs-static-ports.conf
    printf "fs.nfs.nlm_udpport = 32768\n" >> /etc/sysctl.d/nfs-static-ports.conf
}

function nfs_configure_exports {
    cat <<EOT >> "/etc/exports"
# /etc/exports: the access control list for filesystems which may be exported
#		to NFS clients.  See exports(5).
#
# Example for NFSv2 and NFSv3:
# /srv/homes       hostname1(rw,sync,no_subtree_check) hostname2(ro,sync,no_subtree_check)
#
# Example for NFSv4:
# /srv/nfs4        gss/krb5i(rw,sync,fsid=0,crossmnt,no_subtree_check)
# /srv/nfs4/homes  gss/krb5i(rw,sync,no_subtree_check)
#

${NFS_SHARED_HOME} *(rw,subtree_check,root_squash)
${NFS_INSTALLER_DIR} *(rw,subtree_check,root_squash)
EOT
}

function nfs_configure {
    log "Configuring NFS server..."

    nfs_configure_ports
    nfs_configure_exports

    log "Restarting NFS server"
    sysctl --system
    systemctl restart nfs-config
    systemctl restart nfs-server
    systemctl restart rpc-statd.service

    log "Start NFS server on system startup"
    systemctl enable nfs-server
    systemctl enable rpc-statd.service

    log "NFS server configuration has been completed!"
}

function bbs_install_nfs_client {
    log "Installing NFS client"
    pacapt install --noconfirm nfs-common
    log "Done installing NFS client"
}

function install_latest_git {
    log "Install latest version of git from PPA"

    if [[ -n ${IS_REDHAT} ]]
    then
	    pacapt install --noconfirm git2u
    else 
    	apt-add-repository -y ppa:git-core/ppa
	    pacapt update --noconfirm
	    pacapt install --noconfirm git
    fi

    log "Latest version of git has been installed"
}

function bbs_create_installer_dir {
    log "Creating Bitbucket Server installer directory:${NFS_INSTALLER_DIR}"

    mkdir -p "${NFS_INSTALLER_DIR}"
    chown "${BBS_USER}":"${BBS_GROUP}" "${NFS_INSTALLER_DIR}"

    log "Done creating Bitbucket Server installer directory:${NFS_INSTALLER_DIR}!"
}

function bbs_create_shared_home {
    log "Creating Bitbucket Server shared home [directory=${BBS_SHARED_HOME}]"

    mkdir -p "${BBS_SHARED_HOME}"
    chown "${BBS_USER}":"${BBS_GROUP}" "${BBS_SHARED_HOME}"

    log "Done creating Bitbucket Server shared home [directory=${BBS_SHARED_HOME}]!"
}

function bbs_mount_installer_dir {
    local msg_header="Mounting BitBucket Server installer directory"
    local msg_source="[server=${BBS_NFS_SERVER_IP}, directory=${NFS_INSTALLER_DIR}]"
    local msg_target="[directory=${NFS_INSTALLER_DIR}]"
    local msg_opts="[options=${BBS_SHARED_HOME_MOUNT_OPTS}]"
    log "${msg_header} ${msg_source} to ${msg_target} with ${msg_opts}"

    mount -t nfs "${BBS_NFS_SERVER_IP}":"${NFS_INSTALLER_DIR}" -o "${BBS_SHARED_HOME_MOUNT_OPTS}" "${NFS_INSTALLER_DIR}"

    log "Done mounting BitBucket Server installer directory [server=${BBS_NFS_SERVER_IP}, directory=${NFS_INSTALLER_DIR}] to [directory=${NFS_INSTALLER_DIR}]!"
}

function bbs_mount_shared_home {
    local msg_header="Mounting BitBucket Server shared home"
    local msg_source="[server=${BBS_NFS_SERVER_IP}, directory=${NFS_SHARED_HOME}]"
    local msg_target="[directory=${BBS_SHARED_HOME}]"
    local msg_opts="[options=${BBS_SHARED_HOME_MOUNT_OPTS}]"
    log "${msg_header} ${msg_source} to ${msg_target} with ${msg_opts}"

    mount -t nfs "${BBS_NFS_SERVER_IP}":"${NFS_SHARED_HOME}" -o "${BBS_SHARED_HOME_MOUNT_OPTS}" "${BBS_SHARED_HOME}"

    log "Done mounting BitBucket Server shared home [server=${BBS_NFS_SERVER_IP}, directory=${NFS_SHARED_HOME}] to [directory=${BBS_SHARED_HOME}]!"
}

function bbs_update_fstab_installer_dir {
    log "Updating /etc/fstab with installer directory mount:"
    log "    from [server=${BBS_NFS_SERVER_IP}, directory=${NFS_INSTALLER_DIR}]"
    log "    to [directory=${NFS_INSTALLER_DIR}]"
    log "    with [options=${BBS_SHARED_HOME_MOUNT_OPTS}]"

    local source="${BBS_NFS_SERVER_IP}:${NFS_INSTALLER_DIR}"
    local target="${NFS_INSTALLER_DIR}"
    local opts="${BBS_SHARED_HOME_MOUNT_OPTS}"
    local type="nfs"

    printf "\n${source}\t${target}\t${type}\t${opts}\t0 0\n" >> /etc/fstab

    log "Done updating /etc/fstab for installer directory!"
}

function bbs_update_fstab_shared_home {
    log "Updating /etc/fstab with shared home mount:"
    log "    from [server=${BBS_NFS_SERVER_IP}, directory=${NFS_SHARED_HOME}]"
    log "    to [directory=${BBS_SHARED_HOME}]"
    log "    with [options=${BBS_SHARED_HOME_MOUNT_OPTS}]"

    local source="${BBS_NFS_SERVER_IP}:${NFS_SHARED_HOME}"
    local target="${BBS_SHARED_HOME}"
    local opts="${BBS_SHARED_HOME_MOUNT_OPTS}"
    local type="nfs"

    printf "\n${source}\t${target}\t${type}\t${opts}\t0 0" >> /etc/fstab

    log "Done updating /etc/fstab for shared home!"
}

function bbs_configure_installer_dir {
    log "Configuring Bitbucket Server installer directory:${BBS_SHARED_HOME}"

    bbs_create_installer_dir
    bbs_mount_installer_dir
    bbs_update_fstab_installer_dir

    log "Done configuring Bitbucket Server installer directory:${BBS_SHARED_HOME}!"
}

function bbs_configure_shared_home {
    log "Configuring Bitbucket Server shared home [directory=${BBS_SHARED_HOME}]"

    bbs_create_shared_home
    bbs_mount_shared_home
    bbs_update_fstab_shared_home

    log "Done configuring Bitbucket Server shared home [directory=${BBS_SHARED_HOME}]!"
}

function bbs_download_installer {

    if [ ! -n "${BBS_CUSTOM_DOWNLOAD_URL}" ]
    then
        log "Will use version: ${BBS_VERSION} but first retrieving latest bitbucket version info from Atlassian..."
        LATEST_INFO=$(curl -L -f --silent https://my.atlassian.com/download/feeds/current/stash.json | sed 's/^downloads(//g' | sed 's/)$//g')
        if [ "$?" -ne "0" ]; then
        error "Could not get latest info installer description from https://my.atlassian.com/download/feeds/current/stash.json"
        fi

        LATEST_VERSION=$(echo ${LATEST_INFO} | jq '.[] | select(.platform == "Unix") |  select(.zipUrl|test("x64")) | .version' | sed 's/"//g')
        LATEST_VERSION_URL=$(echo ${LATEST_INFO} | jq '.[] | select(.platform == "Unix") |  select(.zipUrl|test("x64")) | .zipUrl' | sed 's/"//g')
        log "Latest bitbucket info: $LATEST_VERSION and download URL: $LATEST_VERSION_URL"
    fi

    [ ${BBS_VERSION} = 'latest' ] && bitbucket_version="${LATEST_VERSION}" || bitbucket_version="${BBS_VERSION}"

    [ -n "${BBS_CUSTOM_DOWNLOAD_URL}" ] && local bitbucket_installer_url="${BBS_CUSTOM_DOWNLOAD_URL}/atlassian-bitbucket-${BBS_VERSION}-x64.bin"  || local bitbucket_installer_url=$(echo ${LATEST_VERSION_URL} | sed "s/${LATEST_VERSION}/${bitbucket_version}/g")
    log "Downloading ${ATL_CONFLUENCE_PRODUCT} installer from ${bitbucket_installer_url}"

    local target="${NFS_INSTALLER_DIR}/installer"
    if ! curl -L -f --silent "${bitbucket_installer_url}" -o "${target}" 2>&1
    then
        error "Could not download Bitbucket Server installer from [url=${bitbucket_installer_url}]"
        exit 1
    else
        log "Making Bitbucket Server installer executable..."
        chmod +x "${target}"
    fi

    log "Done downloading Bitbucket Server installer from [url=${bitbucket_installer_url}]"
}

function bbs_prepare_installer_settings {
    local version="${BBS_INSTALLER_VERSION}"
    local home="${BBS_HOME}"

    log "Preparing installer configuration"

    cat <<EOT >> "${BBS_INSTALLER_VARS}"
app.bitbucketHome=${home}
app.defaultInstallDir=${BBS_INSTALL_DIR}
app.install.service\$Boolean=true
executeLauncherAction\$Boolean=false
httpPort=7990
installation.type=DATA_CENTER_INSTALL
launch.application\$Boolean=false
sys.adminRights\$Boolean=true
sys.languageId=en
EOT

    log "Done preparing installer configuration"
}

function bbs_run_installer {
    log "Running Bitbucket Server installer"
    bbs_prepare_installer_settings

    # https://askubuntu.com/questions/695560/assistive-technology-not-found-awterror
    sudo sed -i -e '/^assistive_technologies=/s/^/#/' /etc/java-*-openjdk/accessibility.properties

    ./installer -q -varfile "${BBS_INSTALLER_VARS}"
    if [ "$?" -ne "0" ]; then
      error "Bitbucket Installer failed!!"
    fi
    
    log "Done running Bitbucket Server installer"
}

function bbs_stop {
    log "Stopping Bitbucket Server application..."

    /etc/init.d/atlbitbucket stop

    log "Bitbucket Server application has been stopped"
}

function bbs_prepare_properties {
    log "Generating 'bitbucket.properties' configuration file"
    [ -n "$(echo ${BBS_URL} | grep -i 'https')" ] && local secure="true" || local secure="false"

    local file_temp="${BBS_HOME}/bitbucket.properties"
    local file_target="${BBS_SHARED_HOME}/bitbucket.properties"

    cat <<EOT >> "${file_temp}"
jdbc.driver=${JDBC_DRIVER}
jdbc.url=${JDBC_URL}
jdbc.user=${JDBC_USER}
jdbc.password=${SQL_PASS}

setup.license=${BBS_LICENSE}
setup.displayName=Bitbucket
setup.baseUrl=${BBS_URL}
setup.sysadmin.username=${BBS_ADMIN}
setup.sysadmin.password=${BBS_PASS}
setup.sysadmin.displayName=${BBS_NAME}
setup.sysadmin.emailAddress=${BBS_EMAIL}

plugin.ssh.baseurl=${BBS_SSH_URL}

hazelcast.port=${BBS_HAZELCAST_PORT}
hazelcast.network.azure=true
hazelcast.network.azure.cluster.id=${BBS_HAZELCAST_CLUSTER_ID}
hazelcast.network.azure.group.name=${BBS_HAZELCAST_GROUP_NAME}
hazelcast.network.azure.subscription.id=${BBS_HAZELCAST_SUBSCRIPTION_ID}

plugin.search.elasticsearch.baseurl=${BBS_ES_BASE_URL}

server.secure=${secure}
jmx.enabled=true
EOT

    chown "${BBS_USER}":"${BBS_GROUP}" "${file_temp}"
    sudo -u "${BBS_USER}" mv -n "${file_temp}" "${file_target}"

    log "Done generating 'bitbucket.properties' configuration file"
}

function install_oms_linux_agent {
  atl_log install_oms_linx_agent "Have OMS Workspace Key? |${OMS_WORKSPACE_ID}|"
  if [[ -n ${OMS_WORKSPACE_ID} ]]; then
    atl_log install_oms_linx_agent  "Installing OMS Linux Agent with workspace id: ${OMS_WORKSPACE_ID} and primary key: ${OMS_PRIMARY_KEY}"
    wget https://raw.githubusercontent.com/Microsoft/OMS-Agent-for-Linux/master/installer/scripts/onboard_agent.sh && sh onboard_agent.sh -w "${OMS_WORKSPACE_ID}" -s "${OMS_PRIMARY_KEY}" -d opinsights.azure.com
    atl_log install_oms_linx_agent  "Finished installing OMS Linux Agent!"
  fi
}

function configure_bitbucket_jmx {
  atl_log configure_bitbucket_jmx "Switching on BitBucket JMX"

  cp -p ${BBS_INSTALL_DIR}/bin/set-jmx-opts.sh ${BBS_INSTALL_DIR}/bin/set-jmx-opts.sh.orig
  echo "export JMX_OPTS='-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=9999 -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false'" > ${BBS_INSTALL_DIR}/bin/set-jmx-opts.sh
}


function check_collectd_java_linking {
  # https://github.com/collectd/collectd/issues/635
  # Applied to both RHEL 7.5, Ubuntu 18.04 (but not 16.04)
  [ -n "$(ldd /usr/lib/collectd/java.so | grep 'not found')" ] && atl_log check_collectd_java_linking "CollectD Java linking error found!!"
}

function install_appinsights_collectd {
  # Have moved collectd to run after BitBucket startup - doesn't start up well with all the mounting/remounting/Confluence not being up.
  if [ -n "${APPINSIGHTS_INSTRUMENTATION_KEY}" ]
  then
    atl_log install_appinsights_collectd "Configuring collectd to publish BitBucket JMX"

    atl_log install_appinsights_collectd  "Configuring App Insights template: ${BBS_INSTALL_DIR}/app/WEB-INF/classes/ApplicationInsights.xml"
    envsubst '$APPINSIGHTS_INSTRUMENTATION_KEY $APPINSIGHTS_VER' < bitbucket-collectd.conf.template > bitbucket-collectd.conf

    if [[ -n ${IS_REDHAT} ]]
    then
      # https://bugs.centos.org/view.php?id=15495
      pacapt install --noconfirm collectd collectd-generic-jmx.x86_64 collectd-java.x86_64 collectd-sensors.x86_64 collectd-rrdtool.x86_64 glib2.x86_64
      ln -sf /usr/lib64/collectd /usr/lib/collectd

      # https://github.com/collectd/collectd/issues/635
      ln -sf /etc/alternatives/jre/lib/amd64/server/libjvm.so /lib64
      check_collectd_java_linking
      cp -fp bitbucket-collectd.conf /etc/collectd.d
      chmod +r /etc/collectd.d/*.conf

      # Disable SELINUX - prevents Collectd logfile writing to /var/log
      # https://serverfault.com/questions/797039/collectd-permission-denied-to-log-file
      setenforce 0
      sed --in-place=.bak 's/SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
    else
      pacapt install --noconfirm collectd
      
      # Use JDK11 libjvm.so if exists or fall back on Java 8 to plug gaps in collectd library path issues.
      [ -f /usr/lib/jvm/java-8-openjdk-amd64/jre/lib/amd64/server/libjvm.so ] && ln -sf /usr/lib/jvm/java-8-openjdk-amd64/jre/lib/amd64/server/libjvm.so /lib/x86_64-linux-gnu/
      [ -f /usr/lib/jvm/java-11-openjdk-amd64/lib/server/libjvm.so ] && ln -sf /usr/lib/jvm/java-11-openjdk-amd64/lib/server/libjvm.so /lib/x86_64-linux-gnu/
      
      check_collectd_java_linking
      cp -fp bitbucket-collectd.conf /etc/collectd/collectd.conf
      chmod +r /etc/collectd/collectd.conf
    fi

    # Jaxb now required for JDK > 8 for AppInsights + Collectd. Ubuntu Collectd now compiled/using JDK 11 as no choice
    curl -LO http://central.maven.org/maven2/javax/xml/bind/jaxb-api/2.3.1/jaxb-api-2.3.1.jar

    atl_log install_appinsights_collectd "Copying collectd appinsights jar to /usr/share/collectd/java"
    cp -fp applicationinsights-collectd*.jar jaxb-api-2.3.1.jar /usr/share/collectd/java/

    atl_log install_appinsights_collectd "Starting collectd..."
    systemctl start collectd
    
    # Bouncing collectd - cgroups issue with Azure wagent
    sleep 5
    systemctl restart collectd
  fi
}

function disable_rhel_firewall {
  if [[ -n ${IS_REDHAT} ]]
  then
    atl_log disable_rhel_firewall  "Disabling RHEL Firewall - using Azure Cluster NSG to maintain access rules"
    systemctl stop firewalld.service
    systemctl disable firewalld.service
  fi
}

function download_appinsights_jars {
  atl_log download_appinsights_jars "Downloading MS AppInsight Jars"
  JARS="applicationinsights-core-${APPINSIGHTS_VER}.jar applicationinsights-web-${APPINSIGHTS_VER}.jar applicationinsights-collectd-${APPINSIGHTS_VER}.jar" 
  for aJar in $(echo $JARS)
  do
     curl -LO https://github.com/Microsoft/ApplicationInsights-Java/releases/download/${APPINSIGHTS_VER}/${aJar}
     if [ $aJar != "applicationinsights-collectd-${APPINSIGHTS_VER}.jar" ]
     then
          atl_log download_appinsights_jars "Copying appinsights jar: ${aJar} to ${1}"
          cp -fp ${aJar} ${1}
     fi
  done
}

function install_appinsights {
  atl_log install_appinsights "Installation MS App Insights"
  atl_log install_appinsights "Have AppInsights Key? |${APPINSIGHTS_INSTRUMENTATION_KEY}|"
  if [ -n "${APPINSIGHTS_INSTRUMENTATION_KEY}" ] 
  then 
     atl_log install_appinsights "Installing App Insights"
     download_appinsights_jars ${BBS_INSTALL_DIR}/app/WEB-INF/lib

     atl_log install_appinsights "Configuring App Insights filter: ${BBS_INSTALL_DIR}/app/WEB-INF/classes/bitbucket-plugin.xml"
     cp -p ${BBS_INSTALL_DIR}/app/WEB-INF/classes/bitbucket-plugin.xml ${BBS_INSTALL_DIR}/app/WEB-INF/classes/bitbucket-plugin.xml.orig
     sed 's_</atlassian-plugin>_<servlet-filter key="applicationInsightsWebFilter" class="com.microsoft.applicationinsights.web.internal.WebRequestTrackingFilter"> <url-pattern>/*</url-pattern> <location>after-encoding</location> <system>true</system> <dispatcher>REQUEST</dispatcher> <dispatcher>FORWARD</dispatcher> <dispatcher>ERROR</dispatcher> <dispatcher>INCLUDE</dispatcher> </servlet-filter> <servlet-context-listener name="applicationInsightsWebListener" key="applicationInsightsWebListener" class="com.microsoft.applicationinsights.web.internal.ApplicationInsightsServletContextListener"/> </atlassian-plugin>_' ${BBS_INSTALL_DIR}/app/WEB-INF/classes/bitbucket-plugin.xml.orig > ${BBS_INSTALL_DIR}/app/WEB-INF/classes/bitbucket-plugin.xml

     atl_log install_appinsights "Configuring App Insights template: ${BBS_INSTALL_DIR}/app/WEB-INF/classes/ApplicationInsights.xml"
     envsubst '$APPINSIGHTS_INSTRUMENTATION_KEY' < ApplicationInsights.xml.template > ${BBS_INSTALL_DIR}/app/WEB-INF/classes/ApplicationInsights.xml

     configure_bitbucket_jmx
  fi
}

function bbs_configure {
    log "Configuring Bitbucket Server application"

    bbs_prepare_properties

    log "Done configuring Bitbucket Server application"
}

function install_postgres_cert_if_needed {
    if [[ -n $(echo $JDBC_URL | grep 'postgres') ]]
    then
        log "Downloading + configuring Azure Postgres cert"
        # https://docs.microsoft.com/en-us/azure/postgresql/concepts-ssl-connection-security
        curl -LO https://www.digicert.com/CACerts/BaltimoreCyberTrustRoot.crt
        openssl x509 -inform DER -in BaltimoreCyberTrustRoot.crt -text -out root.crt

        mkdir -p ${BBS_HOME}/.postgresql
        cp -p root.crt ${BBS_HOME}/.postgresql
    fi
}


function bbs_install {
    log "Downloading and running Bitbucket Server installer"

    log "Copy Bitbucket Server installer"
    cp "${NFS_INSTALLER_DIR}/installer" .
    bbs_run_installer

    install_postgres_cert_if_needed

    atl_log bbs_install "Configuring app insights..."
    install_appinsights
    atl_log bbs_install "Done app insights!"
}

function install_common {
    ensure_prerequisites
    prepare_datadisks
    create_bb_owner
}

function esbackup_scheduled_job {
    # Bit of a hack - prob should be Azure lambda
    cat <<EOF > /usr/local/bin/esbackup
#!/bin/bash
curl -i -XPUT -H 'Content-Type:application/json' http://${ES_LOAD_BALANCER_IP}:9200/_snapshot/azureesrepo -d '{ "type" : "azure", "settings": {"compress":true} }'
curl -i -XPUT -H 'Content-Type:application/json' http://${ES_LOAD_BALANCER_IP}:9200/_snapshot/azureesrepo/bbkupsnapshot-\$(date '+%F_%T')
EOF

    chmod +x /usr/local/bin/esbackup

    crontab -l > /tmp/$$.crontab.tmp
    printf '0 * * * * bash /usr/local/bin/esbackup 2>&1\n' >> /tmp/$$.crontab.tmp
    crontab /tmp/$$.crontab.tmp
}


function install_nfs {
    log "Configuring NFS node..."

    install_common
    install_oms_linux_agent
    disable_rhel_firewall

    nfs_install_server
    nfs_prepare_shared_home
    nfs_prepare_installer_dir
    nfs_configure

    download_appinsights_jars `pwd`
    install_appinsights_collectd

    esbackup_scheduled_job
    log "Done configuring NFS node!"
}

function install_bbs {
    env | sort 

    # NFS_SERVER_IP comes from outside
    BBS_NFS_SERVER_IP="${NFS_SERVER_IP}"

    log "Configuring Bitbucket Server node..."

    install_common
    install_latest_git
    bbs_install_nfs_client
    bbs_configure_shared_home
    bbs_configure_installer_dir

    bbs_configure
    install_oms_linux_agent
    bbs_install
    disable_rhel_firewall
    
    log "Starting Bitbucket Server..."    
    systemctl start atlbitbucket

    install_appinsights_collectd
    log "Done configuring Bitbucket Server node!"
}

function install_unsupported {
    error "Unsupported installation option, abort"
}

function uninstall_bbs {
    log "Stopping Bitbucket Server..."  
    systemctl stop atlbitbucket

    log "Unmounting ${BBS_SHARED_HOME}"
    umount ${BBS_SHARED_HOME}

    log "Unmounting ${NFS_INSTALLER_DIR}"
    umount ${NFS_INSTALLER_DIR}

    log "Removing ${BBS_INSTALL_DIR}"
    rm -rf "${BBS_INSTALL_DIR}"

    log "Removing ${BBS_HOME}"
    rm -rf "${BBS_HOME}"
    rm /etc/init.d/atlbitbucket
    userdel ${BBS_USER}
}

function install_pacapt {
  wget -O /usr/local/bin/pacapt https://github.com/icy/pacapt/raw/ng/pacapt
  sudo chmod 755 /usr/local/bin/pacapt
}

function install_redhat_epel_if_needed {
  if [[ -n ${IS_REDHAT} ]]
  then
	  wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
	  yum install -y ./epel-release-latest-*.noarch.rpm

      wget https://rhel7.iuscommunity.org/ius-release.rpm
	  yum install -y ius-release.rpm
  fi
}

function install_core_dependencies {
  # Seeing consistent issues on Azure where apt/yum not get full list of azure repos and then not able to install dependencies.
  pacapt update --noconfirm
  sleep 5
  pacapt update --noconfirm
  
  # Packages done on different lines as yum command will fail if unknown package defined. Some future proofing.
  pacapt install --noconfirm cifs-utils
  pacapt install --noconfirm nfs-utils
  pacapt install --noconfirm curl
  pacapt install --noconfirm rsync
  pacapt install --noconfirm nc
  pacapt install --noconfirm netcat
  pacapt install --noconfirm jq
  pacapt install --noconfirm gettext

  # nc/nmap-ncat needed on RHEL jumpbox for SSH proxying
  [ -n "${IS_REDHAT}" ] && pacapt install --noconfirm java-1.8.0-openjdk-headless nc || pacapt install --noconfirm openjdk-8-jre-headless

  # RHEL BB Installer font nullpointer issue - https://github.com/AdoptOpenJDK/openjdk-build/issues/693
  [ -n "${IS_REDHAT}" ] && pacapt install --noconfirm fontconfig
}


###############################################################################################################
## Start here
###############################################################################################################

# Spit out args
for (( i=1; i<="$#"; i++ ))
do
  atl_log main "Arg $i: ${!i}"
done

case "$1" in
    nfs) install_nfs;;
    bbs) install_bbs;;
    uninstall_bbs) uninstall_bbs;;
    *) install_unsupported;;
esac

atl_log main "Finished installation!"