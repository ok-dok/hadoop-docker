#!/bin/bash
script=$0

getconf(){
    FILE=$1
    NAME=$2
    col=`grep -n "$NAME" $FILE | awk -F ':' '{print int($1)+1}'`
    sed -n "${col}p" $FILE | sed 's/\s*<value>\(.*\)<\/value>/\1/g'
}

setconf(){
    FILE=$1
    NAME=$2
    NEW_VAL=$3
    col=`grep -n "$NAME" $FILE | awk -F ':' '{print int($1)+1}'`
    old_val=`sed -n "${col}p" $FILE | sed 's/\s*<value>\(.*\)<\/value>/\1/g'`
    echo $new_val
    sed -i "${col}s#${old_val}#${NEW_VAL}#g" $FILE
}

help(){
    echo "Usage: $script <COMMAND> [OPTIONS]"
    echo "Commands:"
    echo "  getconf                 get the value that name match to PROPERTY_NAME from the conf file."
    echo "  setconf                 set the value that name match to PROPERTY_NAME to the conf file."
    echo "Options:"
    echo "  --file <CONF_FILE>      the hadoop conf file to locate."
    echo "  --name <PROPERY_NAME>   the property name to find."
    echo "  --value <NEW_VALUE>     the new value to replace old value."
}


if [[ "$1" = "getconf" ]]; then
    CMD=$1
elif [[ "$1" = "setconf" ]]; then
    CMD=$1
else
    help
    exit 1
fi

shift

ARGS=`getopt -o f:n:v: --l file:,name:,value: -n "$script --help" -- "$@"`
if [ $? != 0 ]; then
    help
    exit 1
fi
eval set -- "${ARGS}"
while [ $# -gt 0 ]; do
    case $1 in
        -f|--file)
            FILE=$2
            shift 2
        ;;
        -n|--name)
            NAME=$2
            shift 2
        ;;
        -v|--value)
            VALUE=$2
            shift 2
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

if [[ "$CMD" = "getconf" ]]; then
     getconf $FILE $NAME
fi

if [[ "$CMD" = "setconf" ]]; then
    setconf $FILE $NAME $VALUE
fi