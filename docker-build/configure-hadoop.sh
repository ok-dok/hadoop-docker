#!/bin/sh

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
    column=`grep -n 'ha.zookeeper.quorum'  ${HADOOP_CONF_DIR}/core-site.xml | awk -F ':' '{print int($1)+1}'`
    gosu hadoop sed -i "${column}c <value>${zkServers}</value>" ${HADOOP_CONF_DIR}/core-site.xml
    # yarn 
    column=`grep -n 'hadoop.zk.address'  ${HADOOP_CONF_DIR}/yarn-site.xml | awk -F ':' '{print int($1)+1}'`
    gosu hadoop sed -i "${column}c <value>${zkServers}</value>" ${HADOOP_CONF_DIR}/yarn-site.xml
fi

# Configure journalnodes 
if [ -n "$HDFS_JOURNAL_NODES" ]; then 
    journodes=`echo $HDFS_JOURNAL_NODES | sed 's/[, ]/;/g'`
    column=`grep -n 'dfs.namenode.shared.edits.dir'  ${HADOOP_CONF_DIR}/hdfs-site.xml | awk -F ':' '{print int($1)+1}'`
    gosu hadoop sed -i "${column}c <value>qjournal://${journodes}/nncluster</value>" ${HADOOP_CONF_DIR}/hdfs-site.xml
fi

