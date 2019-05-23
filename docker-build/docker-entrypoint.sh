#!/bin/sh
set -e

. /etc/profile >/dev/null  2>&1

service ssh start

/configure-hadoop.sh

if [ "$1" = '-m' ]; then
  /start-dfs-cluster.sh
  /start-yarn-cluster.sh
  shift
fi

if [ "$1" = "-d" ]; then
  while true ; do sleep 1000; done
fi
exec "$@"
