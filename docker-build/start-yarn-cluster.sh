#!/usr/bin/env bash
su - hadoop

bin=$HADOOP_HOME/bin

HADOOP_LIBEXEC_DIR="${HADOOP_HOME}/libexec"

# shellcheck disable=SC2034
HADOOP_NEW_CONFIG=true
if [[ -f "${HADOOP_LIBEXEC_DIR}/yarn-config.sh" ]]; then
    . "${HADOOP_LIBEXEC_DIR}/yarn-config.sh"
else
    echo "ERROR: Cannot execute ${HADOOP_LIBEXEC_DIR}/yarn-config.sh." 2>&1
    exit 1
fi
logicals=$("${HADOOP_HOME}/bin/hdfs" getconf -confKey yarn.resourcemanager.ha.rm-ids 2>&-)
logicals=${logicals//,/ }
for id in ${logicals}
do
    rmhost=$("${HADOOP_HOME}/bin/hdfs" getconf -confKey "yarn.resourcemanager.hostname.${id}" 2>&-)
    RMHOSTS="${RMHOSTS} ${rmhost}"
done

echo "Starting resourcemanagers on [${RMHOSTS}]"
for rmhost in $RMHOSTS ; do
    echo -n "$rmhost: "
    ssh $rmhost "$HADOOP_HOME/sbin/yarn-daemon.sh --config '${HADOOP_CONF_DIR}' start resourcemanager" 2>&1
done

echo "Starting nodemanagers"
$HADOOP_HOME/sbin/yarn-daemons.sh \
    --config "${HADOOP_CONF_DIR}" start nodemanager

echo "Starting proxyserver"
$HADOOP_HOME/sbin/yarn-daemon.sh \
    --config "${HADOOP_CONF_DIR}" start proxyserver
