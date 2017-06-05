#!/bin/bash
#
# OCR images of text and combine result into PDF
#
# 1. Make sure they're png, otherwise convert
# 2. Create OCR and output to PDF with tesseract
# 3. Combine into final PDF


png=true
lang='eng'
tempdir=`echo $TMPDIR`
number=$RANDOM
number="00$number"
number=${number: -5}
workdir="$tempdir$number"_tesseract
finalname=final_$number.pdf

# Function to get dpi for 8.5 x 11 paper size (to nearest 10)
function get_dpi {
	size=`convert "$1" -format "%w x %h" info:`
	width=${size%% *}
	height=${size##* }
	if [[ $height -lt $width ]]
	then
	  # landscape orientation
	  dpi=`echo $(( (width / 11 + 5 )  / 10 * 10))`
	  h=`echo $(( 10 * height / dpi ))`
	  maxheight=11
	else
	  # portrait orientation
	  dpi=`echo $(( (height / 11 + 5 )  / 10 * 10))`
	  h=`echo $(( 10 * height / dpi ))`
	  maxheight=85
	fi
	while [[ $h -gt $maxheight ]]
	do
	  dpi=`echo $(( dpi + 10 ))`
	  h=`echo $(( height / dpi ))`
	  echo $dpi
	done
}

# set up functions to report Usage and Usage with Description
PROGNAME=`type $0 | awk '{print $3}'`       # search for convert executable on path
PROGDIR=`dirname $PROGNAME`                 # extract directory of program
PROGNAME=`basename $PROGNAME`               # base name of program

# Read flags

while test $# -gt 0; do
  case "$1" in
    -h|--help)
      echo "$PROGNAME [options] input_file [output_file]"
      echo ''
      echo "options:"
      echo "-h, --help      show brief help"
      echo "-l <language>   specify a tesseract 3-letter language code"
      echo ''
      echo "This script takes an input file and uses tesseract to perform OCR on it,"
      echo "and then creates an output PDF in the same directory."
      echo ''
      echo "All files in the directory with the same starting letter and extension"
      echo "as the input file will be processed."
      echo ''
      echo "If an output file is provided, it will be used with the extension \"pdf\" appended to it, if needed."
      echo "If no output file is provided \"final_xxxxx.pdf\" will be used, where xxxxx are random numbers."
      echo "Any existing file with the same name will be overwritten silently."
      exit 0
      ;;
    -l)
      shift
      lang=$1
      shift
      ;;
    *)
      break
      ;;
  esac
done

# Remaining input should be the input file name with optional output filename
# Make sure it has the right extension
input="$1"
if [[ $# > 1 ]]
then
  finalname="$2"
  finalextension="${finalname##*.}"
  if [[ $finalextension != 'pdf' ]]
  then
    finalname=$finalname.pdf
  fi
fi

# Make sure file exists
if [[ ! -s "$1" ]]
then
  echo ''
  echo -e "\a"File "$1" does not appear to exist! Exiting...
  echo ''
  exit 0
fi

# Get absolute path
filename=`basename "$1"`
firstchar=${filename:0:1}
input=$(cd "$(dirname "$1")"; pwd)/"$filename"
extension="${input##*.}"
dir=`dirname "$input"`
#dir=`echo $dir | sed "s/ /\\\\\ /g"`
pngdir=$dir
mkdir $workdir

# OCR and save to PDF
if [[ $extension != 'png' ]]
then
  png=false
  pngdir=$workdir
  # Convert to png which tesseract leaves alone when making PDF
  for i in `cd "$dir"; ls $firstchar*.$extension`
  do
    dpi=`get_dpi "$dir/$i"`
	output=`basename "$i"`
	output=${output%.*}
    convert -units PixelsPerInch "$dir/$i" -density $dpi "$pngdir/$output.png"
  done
fi

for i in `ls "$pngdir/"*".png"`
do
  filename=`basename $i`
  tesseract -l $lang "$i" "$workdir/$filename"
done

sleep 3
pdfunite $workdir/*.pdf "$dir/$finalname"
