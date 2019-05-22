#!/bin/sh
set -e

. /etc/profile >/dev/null  2>&1

service ssh start

configure() {
  # if [[ -n "$HADOOP_WORKER_NAMES" ]]; then
    # echo > $HADOOP_CONF_DIR/workers
    # echo > $HADOOP_CONF_DIR/slaves
    for worker in $HADOOP_WORKER_NAMES; do
      echo "$worker" >> $HADOOP_CONF_DIR/workers
      echo "$worker" >> $HADOOP_CONF_DIR/slaves
    done
  # fi

  # Configure zookeeper servers
  zkServers=`echo ${ZK_SERVERS} | sed 's/[ ;]/,/g'`
  column=`grep -n 'ha.zookeeper.quorum'  ${HADOOP_CONF_DIR}/core-site.xml | awk -F ':' '{print int($1)+1}'`
  sed -i "${column}c <value>${zkServers}</value>" ${HADOOP_CONF_DIR}/core-site.xml
  column=`grep -n 'hadoop.zk.address'  ${HADOOP_CONF_DIR}/yarn-site.xml | awk -F ':' '{print int($1)+1}'`
  sed -i "${column}c <value>${zkServers}</value>" ${HADOOP_CONF_DIR}/yarn-site.xml
  # Configure journalnodes 
  journodes=`echo $HDFS_JOURNAL_NODES | sed 's/[, ]/;/g'`
  column=`grep -n 'dfs.namenode.shared.edits.dir'  ${HADOOP_CONF_DIR}/hdfs-site.xml | awk -F ':' '{print int($1)+1}'`
  sed -i "${column}c <value>qjournal://${journodes}/nncluster</value>" ${HADOOP_CONF_DIR}/hdfs-site.xml

}

configure

if [ "$1" = '-m' ]; then
  # # Step 3: format zookeeper
  # echo Y | /bootstrap.sh -f zk
  # # Step 1: start journalnodes cluster
  # /bootstrap.sh -s journalnode
  # # Step 2: format namenode 
  # echo N | /bootstrap.sh -f namenode
  # # Step 4: start dfs cluster(contains namenodes, datanodes, ZK Failover controllers)
  # /bootstrap.sh -s dfs
  # # # Step 5: start yarn cluster
  # /bootstrap.sh -s yarn
  # # # Then you should run command "/bootstrap.sh -b" on annother namenode server.
  /start-dfs-cluster.sh
  /start-yarn-cluster.sh
  shift
fi

if [ "$1" = "-d" ]; then
  while true ; do sleep 1000; done
fi
exec "$@"
