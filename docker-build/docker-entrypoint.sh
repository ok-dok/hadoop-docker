#!/bin/sh
set -e

. /etc/profile >/dev/null  2>&1

service ssh start

configure() {
  # for worker in $HADOOP_WORKER_NAMES; do
  #   echo "$worker" >> $HADOOP_CONF_DIR/workers
  # done

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

help(){
  echo "Usage: $0 [OPTIONS]"
  echo "Options:"
  echo "  -m, --master        set this server start as master server, it will format the namenode if necessary, format the zookeeper cluster, start the hdfs cluster and the yarn cluster"
  echo "  -s, --standby       set this server start as master-standby server"
  echo "  -j, --journalnode   set this server start as journalnode server "
  echo "  -l, --log           print logs"
  echo "  -d                  keep running"
  echo "      --help          show help"
}
ARGS=`getopt -o msjdl --l master,standby,journalnode,log -n "$0 --help" -- "$@"`
if [ $? != 0 ]; then
    help
    exit 1
fi
eval set -- "${ARGS}"

detach=0
log=0
while [ $# -gt 0 ]
do
  case $1 in
    -m|--master)
      # step 2:  format the namenode on any namenode server
      gosu hadoop echo N | gosu hadoop hdfs namenode -format
      # step 3: format the zookeeper on any namenode server
      echo N | gosu hadoop $HADOOP_HOME/bin/hdfs zkfc -formatZK
      # step 6: start dfs service on any namenode server
      gosu hadoop $HADOOP_HOME/sbin/start-dfs.sh
      # step 7: start yarn service on any resourcemananger server node
      gosu hadoop $HADOOP_HOME/sbin/start-yarn.sh
      shift
    ;;
    -s|--standby)
      # step 5: bootstrap standby on namenode standby server
      echo N | gosu hadoop $HADOOP_HOME/bin/hdfs namenode -bootstrapStandby
      shift
    ;;
    -j|--journalnode)
      # step 1: start the journalnode on every journalnode server
      gosu hadoop $HADOOP_HOME/sbin/hdfs --daemon start journalnode
      # step 4: initialize journalnode on every journalnode server
      echo N | gosu hadoop $HADOOP_HOME/bin/hdfs namenode -initializeSharedEdits
      shift
    ;;
    -l|--log)
      log=1
      shift
    ;;
    -d)
      detach=1
      shift
    ;;
    --help)
      help
      exit 0
    ;;
    --)
      shift 
      break
    ;;
    *)
      help
      exit 1
    ;;
  esac
done

if [ $log -eq 1]; then
  tail -f $HADOOP_HOME/logs/hadoop-hadoop-datanode-*.log $HADOOP_HOME/logs/hadoop-hadoop-namenode-*.log 
fi
if [ $detach -eq 1 ]; then
  while true; do sleep 1000; done
fi

exec "$@"
