#!/bin/bash
# Quickie script to get all images listed by URIs in a text file.
# Images are stored in a directory inside the dir that contains the list.

list=`cat $1`
dir=`dirname $1`
datestamp=`date "+%Y%m%d-%H%M%S"`
dir="$dir/$datestamp"_downloaded_images

if [[ -e $dir ]]
then
  echo ''
  echo -e "\aThe target directory $dir already exists. Exiting."
  echo ''
  exit 0
fi

mkdir $dir

for i in $list
do
  fname=`basename $i`
  curl $i > $dir/$fname
done
