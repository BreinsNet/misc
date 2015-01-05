#!/bin/bash

PORT=2003
SERVER=example.host.com
METRIC_NAME=smip.$(hostname -f|sed -r 's/\./_/g').lsof_jenkins_user
METRIC_COMMAND='lsof -u jenkins | wc -l'
INTERVAL=10

# Commands

if [[ $1 = "kill" ]]; then
  PIDS=$(ps -fe|grep collect_jenkins_lsof.sh|grep -vE 'grep|kill'|awk '{print $2}')
  for pid in $PIDS;do
    kill $pid
  done
  exit
fi 

if [[ $1 != "nohup" ]]; then
  nohup ./$0 nohup > output.log 2>&1 &
  exit
fi 

# Main loop

while true; do
  sleep $INTERVAL
  METRIC=$(echo "${METRIC_NAME} $(eval ${METRIC_COMMAND}) `date +%s`")
  echo $METRIC | nc ${SERVER} ${PORT}
  echo $METRIC
done

