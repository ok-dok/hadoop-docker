#!/bin/sh

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
    column=`grep -n 'ha.zookeeper.quorum' ${CORE_SITE_FILE} | awk -F ':' '{print int($1)+1}'`
    gosu hadoop sed -i "${column}c <value>${zkServers}</value>" ${CORE_SITE_FILE}
    # yarn 
    column=`grep -n 'hadoop.zk.address' ${YARN_SITE_FILE} | awk -F ':' '{print int($1)+1}'`
    gosu hadoop sed -i "${column}c     <value>${zkServers}</value>" ${YARN_SITE_FILE}
fi

# Configure journalnodes 
if [ -n "$HDFS_JOURNAL_NODES" ]; then 
    journodes=`echo $HDFS_JOURNAL_NODES | sed 's/[, ]/;/g'`
    column=`grep -n 'dfs.namenode.shared.edits.dir' ${HDFS_SITE_FILE} | awk -F ':' '{print int($1)+1}'`
    gosu hadoop sed -i "${column}c     <value>qjournal://${journodes}/nncluster</value>" ${HDFS_SITE_FILE}
fi

# Configure AM's maximum execution attempts.
if [ -n "$YARN_RM_AM_MAX_ATTEMPTS" ]; then
    column=`grep -n 'yarn.resourcemanager.am.max-attempts' ${YARN_SITE_FILE} | awk -F ':' '{print int($1)+1}'`
    gosu hadoop sed -i "${column}c     <value>${YARN_RM_AM_MAX_ATTEMPTS}</value>" ${YARN_SITE_FILE}    
fi

# Configure a container's minimum allocation memory.
if [ -n "$YARN_APP_MIN_MEMORY" ]; then
    column=`grep -n 'yarn.scheduler.minimum-allocation-mb' ${YARN_SITE_FILE} | awk -F ':' '{print int($1)+1}'`
    gosu hadoop sed -i "${column}c     <value>${YARN_APP_MIN_MEMORY}</value>" ${YARN_SITE_FILE}
fi

# Configure a container's maximum allocation memory.
if [ -n "$YARN_APP_MAX_MEMORY" ]; then
    column=`grep -n 'yarn.scheduler.maximum-allocation-mb' ${YARN_SITE_FILE} | awk -F ':' '{print int($1)+1}'`
    gosu hadoop sed -i "${column}c     <value>${YARN_APP_MAX_MEMORY}</value>" ${YARN_SITE_FILE}
fi

# Configure NM's avaliable physical memory.
if [ -n "$YARN_NM_MEMROY" ]; then
    mem_total=$YARN_NM_MEMROY
else
    mem_total=`cat /proc/meminfo | grep MemTotal | tr -cd "[0-9]" | awk '{print int($1/1024/1024)}'`
fi
column=`grep -n 'yarn.nodemanager.resource.memory-mb' ${YARN_SITE_FILE} | awk -F ':' '{print int($1)+1}'`
gosu hadoop sed -i "${column}c     <value>${mem_total}</value>" ${YARN_SITE_FILE}

# Configure NM's virtual memory ratio.
if [ -n "$YARN_NM_VMEM_PMEM_RATIO" ]; then 
    column=`grep -n 'yarn.nodemanager.vmem-pmem-ratio' ${YARN_SITE_FILE} | awk -F ':' '{print int($1)+1}'`
    gosu hadoop sed -i "${column}c     <value>${YARN_NM_VMEM_PMEM_RATIO}</value>" ${YARN_SITE_FILE}
fi

# Configure NM's cpu vcores.
if [ -n "$YARN_NM_CPU_VCORES" ]; then
    cpu_vcores=$YARN_NM_CPU_VCORES
else
    cpu_vcores=`cat /proc/cpuinfo| grep "processor"| wc -l`
fi
column=`grep -n 'yarn.nodemanager.resource.cpu-vcores' ${YARN_SITE_FILE} | awk -F ':' '{print int($1)+1}'`
gosu hadoop sed -i "${column}c     <value>${cpu_vcores}</value>" ${YARN_SITE_FILE}

