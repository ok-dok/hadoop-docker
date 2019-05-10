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

# start_journalnodes(){
#     this="${BASH_SOURCE-$0}"
#     bin=$(cd -P -- "$(dirname -- "${this}")" >/dev/null && pwd -P)

#     # let's locate libexec...
#     if [ -n "${HADOOP_HOME}" ]; then
#     HADOOP_DEFAULT_LIBEXEC_DIR="${HADOOP_HOME}/libexec"
#     else
#     HADOOP_DEFAULT_LIBEXEC_DIR="${bin}/../libexec"
#     fi

#     HADOOP_LIBEXEC_DIR="${HADOOP_LIBEXEC_DIR:-$HADOOP_DEFAULT_LIBEXEC_DIR}"
#     # shellcheck disable=SC2034
#     HADOOP_NEW_CONFIG=true
#     if [ -f "${HADOOP_LIBEXEC_DIR}/hdfs-config.sh" ]; then
#     . "${HADOOP_LIBEXEC_DIR}/hdfs-config.sh"
#     else
#     echo "ERROR: Cannot execute ${HADOOP_LIBEXEC_DIR}/hdfs-config.sh." 2>&1
#     exit 1
#     fi
    
#     JOURNAL_NODES=$("${HADOOP_HDFS_HOME}/bin/hdfs" getconf -journalNodes 2>&-)

#     if [ "${#JOURNAL_NODES}" != 0 ]; then
#     echo "Starting journal nodes [${JOURNAL_NODES}]"

#     hadoop_uservar_su hdfs journalnode "${HADOOP_HDFS_HOME}/bin/hdfs" \
#         --workers \
#         --config "${HADOOP_CONF_DIR}" \
#         --hostnames "${JOURNAL_NODES}" \
#         --daemon start \
#         journalnode
#     (( HADOOP_JUMBO_RETCOUNTER=HADOOP_JUMBO_RETCOUNTER + $? ))
#     fi
# }

ARGS=`getopt -o bf:is: --l bootstrapStandby,format:,initializeSharedEdits,start: -n "$0 --help" -- "$@"`
if [ $? != 0 ]; then
    help
    exit 1
fi
eval set -- "${ARGS}"



while [ $# -gt 0 ]
do
  case $1 in
    -b|--bootstrapStandby)
      # step 5: bootstrap standby on namenode standby server
      gosu hadoop $HADOOP_HOME/bin/hdfs namenode -bootstrapStandby
      shift
    ;;
    -f|--format)
        if [ "$2" = "namenode" ]; then
            gosu hadoop $HADOOP_HOME/bin/hdfs namenode -format
            shift 2
        elif [ "$2" = "zk" ]; then
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
                # start dfs service on any namenode server
                # gosu hadoop $HADOOP_HOME/sbin/start-dfs.sh
                NAMENODES=$(gosu hadoop ${HADOOP_HOME}/bin/hdfs getconf -namenodes 2>/dev/null)

                if [[ -z "${NAMENODES}" ]]; then
                  NAMENODES=$(hostname)
                fi

                echo "Starting namenodes on [${NAMENODES}]"
                gosu hadoop ${HADOOP_HOME}/bin/hdfs \
                    --workers \
                    --config "${HADOOP_CONF_DIR}" \
                    --hostnames "${NAMENODES}" \
                    --daemon start \
                    namenode
                echo "Starting datanodes"
                gosu hadoop ${HADOOP_HOME}/bin/hdfs \
                    --workers \
                    --config "${HADOOP_CONF_DIR}" \
                    --daemon start \
                    datanode 
                shift
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
            ;;
            yarn) 
                # start yarn service on any resourcemananger server node
                gosu hadoop $HADOOP_HOME/sbin/start-yarn.sh
                shift
            ;;
            journalnode)
                # start the journalnode on every journalnode server
                # gosu hadoop $HADOOP_HOME/sbin/hdfs --daemon start journalnode
                # gosu hadoop start_journalnodes
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
                shift
            ;;
            *)
                echo "Command error! Usage: $0 -s|--start dfs|yarn|journalnode"
                echo 'Use "$0 --help" to see more details.'
                exit 1
            ;;
        esac
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
