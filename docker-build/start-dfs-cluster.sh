#!/usr/bin/env bash

# switch to hadoop user.
su - hadoop
. /etc/profile

#---------------------------------------------------------
# format zookeeper
if [[ ! -f "$HADOOP_HOME/format-zk.lock" ]];then
    echo N | $HADOOP_HOME/bin/hdfs zkfc -formatZK
    echo true > $HADOOP_HOME.format-zk.lock
fi

#---------------------------------------------------------
# start ervery quorumjournal node (if any)
 
SHARED_EDITS_DIR=$($HADOOP_HOME/bin/hdfs getconf -confKey dfs.namenode.shared.edits.dir 2>&-)

case "$SHARED_EDITS_DIR" in
qjournal://*)
    JOURNAL_NODES=$(echo "$SHARED_EDITS_DIR" | sed 's,qjournal://\([^/]*\)/.*,\1,g; s/;/ /g; s/:[0-9]*//g')
    echo "Starting journal nodes [$JOURNAL_NODES]"
    $HADOOP_HOME/sbin/hadoop-daemons.sh \
        --config "$HADOOP_CONF_DIR" \
        --hostnames "$JOURNAL_NODES" \
        --script "${HADOOP_HOME}/bin//hdfs" start journalnode ;;
esac

NAMENODES=$(${HADOOP_HOME}/bin/hdfs getconf -namenodes 2>/dev/null)

if [[ -z "${NAMENODES}" ]]; then
  NAMENODES=$(hostname)
fi
OLD_IFS="$IFS" 
IFS=" " 
namenodes=($NAMENODES) 
IFS="$OLD_IFS" 
if [[ ${#namenodes[@]} -le 0 ]]; then
    echo "Error: No namenode."
    exit 1
fi

# first run 
if [[ ! -f "$HADOOP_HOME/format-namenode.lock" ]];then
    #---------------------------------------------------------
    # format namenode, and start namenode on the master namenode.
    ssh ${namenodes[0]} 2>&1 <<EOF
        $HADOOP_HOME/bin/hdfs namenode -format
        $HADOOP_HOME/sbin/hadoop-daemon.sh \
            --config "$HADOOP_CONF_DIR" \
            --script "$HADOOP_HOME/bin/hdfs" start namenode
        exit
EOF
    #---------------------------------------------------------
    # bootstrap and start standby namenode.
    if [[ ${#namenodes[@]} -le 1 ]]; then
        echo "Error: No secondary namenode."
        exit 1
    fi
    ssh ${namenodes[1]} "$HADOOP_HOME/bin/hdfs namenode -bootstrapStandby" 2>&1 
    #---------------------------------------------------------
    #stop the first namenode 
    echo -n "${namenodes[0]}: "
    ssh ${namenodes[0]} "$HADOOP_HOME/sbin/hadoop-daemon.sh \
            --config '$HADOOP_CONF_DIR' \
            --script '$HADOOP_HOME/bin/hdfs' stop namenode" 2>&1
    echo true > $HADOOP_HOME/format-namenode.lock
fi

#---------------------------------------------------------
# start all namenodes
echo "Starting namenodes on [${NAMENODES}]"
$HADOOP_HOME/sbin/hadoop-daemons.sh \
    --config "$HADOOP_CONF_DIR" \
    --hostnames "$NAMENODES" \
    --script "$HADOOP_HOME/bin/hdfs" start namenode

#---------------------------------------------------------
# start all datanodes, using default slaves file
echo "Starting datanodes"
$HADOOP_HOME/sbin/hadoop-daemons.sh \
    --config "$HADOOP_CONF_DIR" \
    --script "$HADOOP_HOME/bin/hdfs" start datanode

#---------------------------------------------------------
# start ZK Failover controllers, if auto-HA is enabled
AUTOHA_ENABLED=$(gosu hadoop ${HADOOP_HOME}/bin/hdfs getconf -confKey dfs.ha.automatic-failover.enabled | tr '[:upper:]' '[:lower:]')
if [[ "${AUTOHA_ENABLED}" = "true" ]]; then
echo "Starting ZK Failover Controllers on NN hosts [${NAMENODES}]"

$HADOOP_HOME/sbin/hadoop-daemons.sh \
    --config "$HADOOP_CONF_DIR" \
    --hostnames "$NAMENODES" \
    --script "$HADOOP_HOME/bin/hdfs" start zkfc
fi
