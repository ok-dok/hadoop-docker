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
  JOURNAL_NODES=$(gosu hadoop ${HADOOP_HOME}/bin/hdfs getconf -journalNodes 2>&-)

  if [ "${#JOURNAL_NODES}" != 0 ]; then
    echo "Starting journal nodes [${JOURNAL_NODES}]"

    gosu hadoop ${HADOOP_HOME}/bin/hdfs \
        --workers \
        --config "${HADOOP_CONF_DIR}" \
        --hostnames "${JOURNAL_NODES}" \
        --daemon start \
        journalnode
  fi
}

NAMENODES=$(gosu hadoop ${HADOOP_HOME}/bin/hdfs getconf -namenodes 2>/dev/null)

if [[ -z "${NAMENODES}" ]]; then
  NAMENODES=$(hostname)
fi
#---------------------------------------------------------
# namenodes
start_namenodes(){
  echo "Starting namenodes on [${NAMENODES}]"
  gosu hadoop ${HADOOP_HOME}/bin/hdfs \
      --workers \
      --config "${HADOOP_CONF_DIR}" \
      --hostnames "${NAMENODES}" \
      --daemon start \
      namenode
}

#---------------------------------------------------------
# datanodes (using default workers file)
start_datanodes(){
  echo "Starting datanodes"
  gosu hadoop ${HADOOP_HOME}/bin/hdfs \
      --workers \
      --config "${HADOOP_CONF_DIR}" \
      --daemon start \
      datanode 
}

#---------------------------------------------------------
# ZK Failover controllers, if auto-HA is enabled
start_zkfc(){
  AUTOHA_ENABLED=$(gosu hadoop ${HADOOP_HOME}/bin/hdfs getconf -confKey dfs.ha.automatic-failover.enabled | tr '[:upper:]' '[:lower:]')
  if [[ "${AUTOHA_ENABLED}" = "true" ]]; then
    echo "Starting ZK Failover Controllers on NN hosts [${NAMENODES}]"

    gosu hadoop ${HADOOP_HOME}/bin/hdfs \
      --workers \
      --config "${HADOOP_CONF_DIR}" \
      --hostnames "${NAMENODES}" \
      --daemon start \
      zkfc
  fi
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
                gosu hadoop $HADOOP_HOME/sbin/start-yarn.sh
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
