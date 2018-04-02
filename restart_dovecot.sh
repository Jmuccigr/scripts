#!/bin/bash

# Kill the dovecot process and restart it
# Useful after upgrade

pid=$(cat /usr/local/var/run/dovecot/master.pid)

if [[ $pid != '' ]]
then
  kill -1 ${pid} >>/dev/null 2>&1
  sleep 1
  kill -15 ${pid} >>/dev/null 2>&1
  sleep 1
  kill -9 ${pid} >>/dev/null 2>&1
fi

brew services stop dovecot
brew services start dovecot
