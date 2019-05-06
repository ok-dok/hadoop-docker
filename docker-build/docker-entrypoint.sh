#!/bin/sh
set -ex

. /etc/profile >/dev/null  2>&1

service ssh start

# for worker in $HADOOP_WORKER_NAMES; do
#   echo "$worker" >> $HADOOP_CONF_DIR/workers
# done

if [ "$1" = "--start-cluster" ]; then
  gosu hadoop echo N | gosu hadoop hdfs namenode -format
  gosu hadoop $HADOOP_HOME/sbin/start-dfs.sh
  gosu hadoop $HADOOP_HOME/sbin/start-yarn.sh
  tail -f $HADOOP_HOME/logs/hadoop-hadoop-datanode-*.log $HADOOP_HOME/logs/hadoop-hadoop-namenode-*.log 
fi

if [ "$1" = "-d" ]; then
  while true; do sleep 1000; done
fi

exec "$@"
