#!/usr/bin/env bash
help(){
  echo "Usage: $0 [OPTIONS]"
  echo "Options:"
  echo "  -b, --bootstrapStandby                Copy over the contents of your NameNode metadata directories to the other, unformatted NameNode(s) by running the command “hdfs namenode -bootstrapStandby” on the unformatted NameNode(s). Running this command will also ensure that the JournalNodes (as configured by dfs.namenode.shared.edits.dir) contain sufficient edits transactions to be able to start both NameNodes."
  echo "  -f, --format  <namenode|zk>           Format the namenode or zkfc"
  echo "  -i, --initializeSharedEdits           Converting a non-HA NameNode to be HA by run the command “hdfs namenode -initializeSharedEdits”, which will initialize the JournalNodes with the edits data from the local NameNode edits directories. "
  echo "  -s, --start   <dfs|yarn|journalnode>  Start the dfs or yarn or journalnode cluster"
  echo "      --help                            Show command help"
}

#---------------------------------------------------------
# quorumjournal nodes (if any)
start_journalnodes(){
  
  SHARED_EDITS_DIR=$($HADOOP_HOME/bin/hdfs getconf -confKey dfs.namenode.shared.edits.dir 2>&-)

  case "$SHARED_EDITS_DIR" in
    qjournal://*)
      JOURNAL_NODES=$(echo "$SHARED_EDITS_DIR" | sed 's,qjournal://\([^/]*\)/.*,\1,g; s/;/ /g; s/:[0-9]*//g')
      echo "Starting journal nodes [$JOURNAL_NODES]"
      gosu hadoop $HADOOP_HOME/sbin/hadoop-daemons.sh \
          --config "$HADOOP_CONF_DIR" \
          --hostnames "$JOURNAL_NODES" \
          --script "${HADOOP_HOME}/bin//hdfs" start journalnode ;;
  esac

}

NAMENODES=$(gosu hadoop ${HADOOP_HOME}/bin/hdfs getconf -namenodes 2>/dev/null)

if [[ -z "${NAMENODES}" ]]; then
  NAMENODES=$(hostname)
fi
#---------------------------------------------------------
# namenodes
start_namenodes(){
  echo "Starting namenodes on [${NAMENODES}]"
  gosu hadoop $HADOOP_HOME/sbin/hadoop-daemons.sh \
    --config "$HADOOP_CONF_DIR" \
    --hostnames "$NAMENODES" \
    --script "$HADOOP_HOME/bin/hdfs" start namenode
}

#---------------------------------------------------------
# datanodes (using default workers file)
start_datanodes(){
  echo "Starting datanodes"
  gosu hadoop $HADOOP_HOME/sbin/hadoop-daemons.sh \
    --config "$HADOOP_CONF_DIR" \
    --script "$HADOOP_HOME/bin/hdfs" start datanode
}

#---------------------------------------------------------
# ZK Failover controllers, if auto-HA is enabled
start_zkfc(){
  AUTOHA_ENABLED=$(gosu hadoop ${HADOOP_HOME}/bin/hdfs getconf -confKey dfs.ha.automatic-failover.enabled | tr '[:upper:]' '[:lower:]')
  if [[ "${AUTOHA_ENABLED}" = "true" ]]; then
    echo "Starting ZK Failover Controllers on NN hosts [${NAMENODES}]"

    gosu hadoop $HADOOP_HOME/sbin/hadoop-daemons.sh \
      --config "$HADOOP_CONF_DIR" \
      --hostnames "$NAMENODES" \
      --script "$HADOOP_HOME/bin/hdfs" start zkfc
  fi
}

start_yarn(){
  MYNAME="${BASH_SOURCE-$0}"

  bin=$(cd -P -- "$(dirname -- "${MYNAME}")" >/dev/null && pwd -P)

  # let's locate libexec...
  if [[ -n "${HADOOP_HOME}" ]]; then
    HADOOP_DEFAULT_LIBEXEC_DIR="${HADOOP_HOME}/libexec"
  else
    HADOOP_DEFAULT_LIBEXEC_DIR="${bin}/../libexec"
  fi

  HADOOP_LIBEXEC_DIR="${HADOOP_LIBEXEC_DIR:-$HADOOP_DEFAULT_LIBEXEC_DIR}"
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
  gosu hadoop $HADOOP_HOME/sbin/yarn-daemon.sh \
    --config "${HADOOP_CONF_DIR}" \
    --hostnames "${RMHOSTS}" start resourcemanager

  echo "Starting nodemanagers"
  gosu hadoop $HADOOP_HOME/sbin/yarn-daemons.sh \
    --config "${HADOOP_CONF_DIR}" start nodemanager
}

ARGS=`getopt -o bf:is:l: --l bootstrapStandby,format:,initializeSharedEdits,start:logs: -n "$0 --help" -- "$@"`
if [ $? != 0 ]; then
    help
    exit 1
fi
eval set -- "${ARGS}"

while [ $# -gt 0 ]
do
  case $1 in
    -b|--bootstrapStandby)
      # After format namenode on one server, then bootstrap standby on another namenode server
      # Running this command will also ensure that the JournalNodes (as configured by dfs.namenode.shared.edits.dir) 
      # contain sufficient edits transactions to be able to start both NameNodes,
      # and you do not need to run command "hdfs namenode -initializeSharedEdits"
      gosu hadoop $HADOOP_HOME/bin/hdfs namenode -bootstrapStandby
      shift
    ;;
    -f|--format)
        if [ "$2" = "namenode" ]; then
            # format namenode on one namenode server, which will be started as active namenode server 
            gosu hadoop $HADOOP_HOME/bin/hdfs namenode -format
            shift 2
        elif [ "$2" = "zk" ]; then
            # format zookeeper on any namenode server
            gosu hadoop $HADOOP_HOME/bin/hdfs zkfc -formatZK
            shift 2
        else
            echo "Command error!"
            help
            exit 1
        fi
    ;;
    -i|--initializeSharedEdits)
        gosu hadoop $HADOOP_HOME/bin/hdfs namenode -initializeSharedEdits
        shift
    ;;
    -s|--start)
        case $2 in
            dfs)
                # start dfs service(contains namenodes, datanodes, zkfc) on any namenode server
                start_namenodes
                start_datanodes
                start_zkfc
            ;;
            yarn) 
                # start yarn service on any resourcemananger server node
                # gosu hadoop $HADOOP_HOME/sbin/start-yarn.sh
                start_yarn
            ;;
            journalnode)
                start_journalnodes
            ;;
            *)
                echo "Command error! Usage: $0 -s|--start dfs|yarn|journalnode"
                echo 'Use "$0 --help" to see more details.'
                exit 1
            ;;
        esac
        shift 2
    ;;
    -l|--logs)
      case $2 in
        jn|journalnode)
          tail -f $HADOOP_HOME/logs/hadoop-hadoop-journalnode-*.log
        ;;
        nn|namenode)
          tail -f $HADOOP_HOME/logs/hadoop-hadoop-namenode-*.log
        ;;
        dn|datanode)
          tail -f $HADOOP_HOME/logs/hadoop-hadoop-datanode-*.log
        ;;
        nm|nodemanager)
          tail -f $HADOOP_HOME/logs/hadoop-hadoop-nodemanager-*.log
        ;;
        rm|resourcemananger)
          tail -f $HADOOP_HOME/logs/hadoop-hadoop-resourcemanager-*.log
        ;;
        zkfc)
          tail -f $HADOOP_HOME/logs/hadoop-hadoop-zkfc-*.log
        ;;
        *)
          echo "Command error! Usage: $0 -l|--logs <OPTIONS>"
          echo 'Use "$0 --help" to see more details.'
          exit 1
        ;;
      esac
      shift 2
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
