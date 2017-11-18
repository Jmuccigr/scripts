#!/bin/bash
#
# Get max dimensions of files in a directory and create new file 10% bigger & all white.
# Then combine files with larger white file as background
#
dir=`dirname "$1"`
finalextension="${1##*.}"
if [[ finalextension != '' ]]
then
    finalextension=".$finalextension"
fi
w=`identify -format "%w\n" "$dir"/*$finalextension | sort -r | head -n 1`
h=`identify -format "%h\n" "$dir"/*$finalextension | sort -r | head -n 1`
hd=$(( h / 20 ))
wd=$(( w / 20 ))
w=$(( w + wd * 2 ))
h=$(( h + hd * 2 ))

# Generate unique white filename from date & time stamp
number=`date "+%Y%m%d%H%M%S"`
finalname=white_$number.png
convert -size "$w"x"$h" -background white xc: $TMPDIR/$finalname

# Create new directory & save converted files in it
# Put existing file 5% down from the top of the background page
# This will consistently treat final pages that are short.
mkdir "$dir/bigger"
cd "$dir"; ls *$finalextension | xargs -I {} convert -gravity north -geometry +0+$hd $TMPDIR/$finalname {} -compose divide_dst -composite bigger/{}
