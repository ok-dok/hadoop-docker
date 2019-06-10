#!/bin/sh
set -e

CORE_SITE_FILE=${HADOOP_CONF_DIR}/core-site.xml
HDFS_SITE_FILE=${HADOOP_CONF_DIR}/hdfs-site.xml
YARN_SITE_FILE=${HADOOP_CONF_DIR}/yarn-site.xml

# Configure hadoop workers
if [ -n "$HADOOP_WORKER_NAMES" ]; then
    gosu hadoop echo > $HADOOP_CONF_DIR/workers
    gosu hadoop echo > $HADOOP_CONF_DIR/slaves
    for worker in $HADOOP_WORKER_NAMES; do
      gosu hadoop echo "$worker" >> $HADOOP_CONF_DIR/workers
      gosu hadoop echo "$worker" >> $HADOOP_CONF_DIR/slaves
    done
fi

# Configure zookeeper servers
if [ -n "$ZK_SERVERS" ]; then
    zkServers=`echo ${ZK_SERVERS} | sed 's/[ ;]/,/g'`
    # hdfs
    /hadoop-tools.sh setconf -f ${CORE_SITE_FILE} -n "ha.zookeeper.quorum" -v "${zkServers}"
    # yarn 
    /hadoop-tools.sh setconf -f ${YARN_SITE_FILE} -n "hadoop.zk.address" -v "${zkServers}"
fi

# Configure journalnodes 
if [ -n "$HDFS_JOURNAL_NODES" ]; then 
    journodes=`echo $HDFS_JOURNAL_NODES | sed 's/[, ]/;/g'`
    nameservice=`/hadoop-tools.sh getconf -f "${HDFS_SITE_FILE}" -n "dfs.nameservices"`
    /hadoop-tools.sh setconf -f ${HDFS_SITE_FILE} -n "dfs.namenode.shared.edits.dir" -v "qjournal://${journodes}/${nameservice}"
fi

# Configure AM's maximum execution attempts.
if [ -n "$YARN_RM_AM_MAX_ATTEMPTS" ]; then
    /hadoop-tools.sh setconf -f ${YARN_SITE_FILE} -n "yarn.resourcemanager.am.max-attempts" -v "${YARN_RM_AM_MAX_ATTEMPTS}"
fi

# Configure a container's minimum allocation memory.
if [ -n "$YARN_APP_MIN_MEMORY" ]; then
    /hadoop-tools.sh setconf -f ${YARN_SITE_FILE} -n "yarn.scheduler.minimum-allocation-mb" -v "${YARN_APP_MIN_MEMORY}"
fi

# Configure a container's maximum allocation memory.
if [ -n "$YARN_APP_MAX_MEMORY" ]; then
    /hadoop-tools.sh setconf -f ${YARN_SITE_FILE} -n "yarn.scheduler.maximum-allocation-mb" -v "${YARN_APP_MAX_MEMORY}"
fi

# Configure NM's avaliable physical memory.
if [ -n "$YARN_NM_MEMROY" ]; then
    mem_total=$YARN_NM_MEMROY
else
    mem_total=`cat /proc/meminfo | grep MemTotal | tr -cd "[0-9]" | awk '{print int($1/1024/1024)}'`
fi
/hadoop-tools.sh setconf -f ${YARN_SITE_FILE} -n "yarn.nodemanager.resource.memory-mb" -v "${mem_total}"

# Configure NM's virtual memory ratio.
if [ -n "$YARN_NM_VMEM_PMEM_RATIO" ]; then 
    /hadoop-tools.sh setconf -f ${YARN_SITE_FILE} -n "yarn.nodemanager.vmem-pmem-ratio" -v "${YARN_NM_VMEM_PMEM_RATIO}"
fi

# Configure NM's cpu vcores.
if [ -n "$YARN_NM_CPU_VCORES" ]; then
    cpu_vcores=$YARN_NM_CPU_VCORES
else
    cpu_vcores=`cat /proc/cpuinfo| grep "processor"| wc -l`
fi
/hadoop-tools.sh setconf -f ${YARN_SITE_FILE} -n "yarn.nodemanager.resource.cpu-vcores" -v "${cpu_vcores}"
