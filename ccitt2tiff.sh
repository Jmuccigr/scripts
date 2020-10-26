#!/bin/sh

# Script to create Group4 compressed tiff files from a ccitt/params file pair
# like those made by pdfimages.
# Pass the script one of the files and it will act on all pairs in that dir,
# creating a sub-directory with a date-stamped name to store the tiffs.

if [[ $# == 0 ]]
then
    set -- "-h"
fi

while test $# -gt 0; do
  case "$1" in
    -h|--help)
      echo ""
      echo "This script will create Group4 compressed tiff files from a ccitt/params file pair"
      echo "like those made by pdfimages."
      echo ""
      echo "Pass the script one of the files and it will act on all pairs in that dir,"
      echo "creating a sub-directory with a date-stamped name to store the tiffs."
      echo ""
      echo "options:"
      echo "-h, --help     Show this brief help."
      exit 0
      ;;
	*)
	break
	;;
  esac
done

filename=$1
working_dir=`dirname "$1"`

datestring=`date +%Y-%m-%d_%H.%M.%S`
dest_dir="$working_dir"/tiff_"$datestring"
mkdir "$dest_dir"

for i in "$working_dir"/*.ccitt
do
  j="${i%.*}"
  k=`basename "$j"`
  param_string=`cat "$j".params`
  # Set appropriate output parameters
  if [[ $param_string == *" -4 "* || $param_string == *" -4" || $param_string == "-4 "*  ]]
  then
    output_param="-8"
    echo 4
  if [[ $param_string == *" -3 "* || $param_string == *" -3" || $param_string == "-3 "*  ]]
  then
    output_param="-7"
  fi
  fax2tiff -o "$dest_dir"/"$k".tiff `cat "$j".params` "$output_param" "$i"
done

terminal-notifier -message "Conversion complete." -title "Yay!" -sound default