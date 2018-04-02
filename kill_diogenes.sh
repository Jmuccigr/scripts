#!/bin/bash

# Check for Diogenes' background process and kill it

_id='diogenes-server.pl'

for die1 in `ps -x | grep ${_id} | grep -v grep | awk '{print $1}'`
do
  kill -1 ${die1} >>/dev/null 2>&1
done
sleep 1
for die2 in `ps -x | grep ${_id} | grep -v grep | awk '{print $1}'`
do
  kill -15 ${die2} #>>/dev/null 2>&1
done
sleep 1
for dienow in `ps -x | grep ${_id} | grep -v grep | awk '{print $1}'`
do
  kill -9 ${dienow} #>>/dev/null 2>&1
done
