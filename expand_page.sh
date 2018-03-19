#!/bin/bash
#
# Get max dimensions of files in a directory and create new file 10% bigger & all white.
# Then combine files with larger white file as background
#
# To-do: add option to specify % increase in size with current set as default.

sizegiven=false
usemax=false
color="white"
side="north"
sidegiven="top"
ext=""
format=""

# Read flags
# Provide help if no argument
if [[ $# == 0 ]]
then
    set -- "-h"
fi

while test $# -gt 0; do
  case "$1" in
    -h|--help)
      echo "A script to take all files in a directory that have the same extension"
      echo "and starting letter and increase their size by putting them"
      echo "on a larger canvas."
      echo ""
      echo "By default the new canvas is white and the size is increased by 10% in"
      echo "both width and height. The old image is placed 5% from the top of"
      echo "the new canvas."
      echo ""
      echo "expand_page.sh [options] input_file"
      echo ""
      echo "options:"
      echo "-h, --help    Show this brief help."
      echo "-color        Set the background color. Default is white."
      echo "              Surround numeric colors by quotation marks, e.g., \"#444\"."
      echo "-size         Create new file at given size. Format should be:"
      echo "              <width>x<height>, where width and height are integers."
      echo "-max          Use maximum existing file dimensions for new size"
      echo "-side <top|bottom|left|right|north|south|east|west|center>"
      echo "              Choose side to align image file. Default is top/north."
      exit 0
      ;;
    -color)
      shift
      color=$1
      shift
      ;;
    -size)
      sizegiven=true
      shift
      size=$1
      shift
      ;;
    -max)
      usemax=true
      shift
      ;;
    -side)
      shift
      sidegiven=$1
      shift
      ;;
    -png)
      ext='.png'
      shift
      ;;
    -ccit)
      ext='.tiff'
      format=' -alpha off -monochrome -compress fax '
      shift
      ;;
    *)
      break
      ;;
  esac
done

# Set the side for alignment. Default is top/north
case "$sidegiven" in
  top|north)
    side="north"
    ;;
  bottom|south)
    side="south"
    ;;
  left|west)
    side="west"
    ;;
  right|east)
    side="east"
    ;;
  center)
    side="center"
    ;;
esac

dir=`dirname "$1"`

# Get extension
finalextension="${1##*.}"
if [[ finalextension != '' ]]
then
    finalextension=".$finalextension"
fi
# Get first character of filename
firstchar=`basename "$1"`
firstchar=${firstchar:0:1}

# Get max width and height
filewxh=`convert -ping +repage -layers trim-bounds -delete 1--1 -format %P "$dir/$firstchar*$finalextension" info:`
filew=`echo $filewxh | sed 's/x.*//'`
fileh=`echo $filewxh | sed 's/.*x//'`

if [[ $sizegiven == true ]]
then
    w=`echo $size | sed 's/x.*//'`
    h=`echo $size | sed 's/.*x//'`
    if [[ w -lt filew ]]
    then
        echo -e "\aWarning: entered width is less than the original files'. Aborting."
        exit 0
    fi
    if [[ h -lt fileh ]]
    then
        echo -e "\aWarning: entered height is less than the original files'. Aborting."
        exit 0
    fi
else
    if [[ $usemax == true ]]
    then
        w=$filew
        h=$fileh
    else
        wd=$(( filew / 20 ))
        hd=$(( fileh / 20 ))
        w=$(( filew + wd * 2 ))
        h=$(( fileh + hd * 2 ))
    fi
fi

# Create new directory & save converted files in it
# Put existing file 5% down from the top of the background page
# This will consistently treat final pages that are short.
mkdir "$dir/resized"
cd "$dir"
ls $firstchar*$finalextension | xargs -I {} convert \( -size "$w"x"$h" -background "$color" xc: -write mpr:bgimage +delete \) -gravity $side -geometry +0+$hd mpr:bgimage {} -compose divide_dst $format -composite "resized/{}$ext"
