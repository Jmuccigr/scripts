#!/bin/bash
#
# OCR images of text and combine result into PDF
#
# 1. If they're not 1-bit, make sure they're png, otherwise convert
# 2. If size is too small for tesseract, enlarge
# 3. Create OCR and output to PDF with tesseract
#    For enlarged files, create blank version with text
#    to merge with original-sized images
# 4. Combine into final PDF

# For 1-bit images:
#    output and then convert to final tiff in this way:
#    convert imagefile -alpha off -monochrome -compress Group4 -quality 100 output.tiff

# Function to get dpi for 8.5 x 11 paper size (to nearest 10)
function get_dpi {
	size=`magick identify -format "%w x %h" "$1"`
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
	done
	echo $dpi
}

# Function to get depth, so we can treat 1-bit images differently
function get_depth {
	dpth=`identify -format %[bit-depth] "$1"`
	echo $dpth
}

# Function to set enlargement value for optimal tesseract OCR
# Recommended at least 300 dpi
function get_enlargement {
	imgDPI=$1
	minDPI=300
	testDPI=`expr $minDPI - 1`
	enlarge=0
	if [[ ! $imgDPI -gt $testDPI ]]
	then
	  newDPI=$imgDPI
	  while [[ ! $newDPI -gt $testDPI ]]
	  do
		enlarge=`echo $(( $enlarge + 1 ))`
        newDPI=`echo $(( $imgDPI * $enlarge))`
	  done
	else
	  enlarge=1
	fi
	echo "$enlarge"00%
}

# Set some variables
tiff=" -define tiff:preserve-compression=true "
startTime=`date +%s`
png=true
lang=''
ignore_ext=false
number=$RANDOM
number="00$number"
number=${number: -5}
finalname=final_$number.pdf

# set up functions to report Usage and Usage with Description
PROGNAME=`type "$0" | awk '{print $3}'`     # search for convert executable on path
PROGNAME=`basename $PROGNAME`               # base name of program

# Read flags
# Provide help if no argument
if [[ $# == 0 ]]
then
    set -- "-h"
fi

while test $# -gt 0; do
  case "$1" in
    -h|--help)
      echo "$PROGNAME [options] input_file [output_file]"
      echo ''
      echo "options:"
      echo "-h, --help      show brief help"
      echo "-i              process files regardless of extension"
      echo "-l <language>   specify a tesseract 3-letter language code"
      echo ''
      echo "This script takes an input file and uses tesseract to perform OCR on it,"
      echo "and then creates an output PDF in the same directory."
      echo ''
      echo "All files in the directory with the same starting letter and extension"
      echo "as the input file will be processed, unless the -i flag is used."
      echo ''
      echo "If an output file is provided, it will be used with the extension \"pdf\" appended to it, if needed."
      echo "If no output file is provided \"final_xxxxx.pdf\" will be used, where xxxxx are random numbers."
      echo "Any existing file with the same name will be overwritten silently."
      exit 0
      ;;
    -i)
      ignore_ext=true
      shift
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
# If wildcard is input, throw an error
# Make sure it has the right extension
optionCount=$#
if [[ $optionCount > 2 ]]
then
  echo "You've entered too many inputs, perhaps a wildcard in the filename?"
  exit 0
fi

input="$1"
if [[ $optionCount > 1 ]]
then
  echo "You entered two arguments, so we'll use the second one for the name of the output file."
  finalname="$2"
  finalextension="${finalname##*.}"
  if [[ $finalextension != 'pdf' ]]
  then
    finalname="$finalname".pdf
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

# Get absolute path & file info
filename=`basename "$1"`
firstchar=${filename:0:1}
input=$(cd "$(dirname "$1")"; pwd)/"$filename"
if [[ $ignore_ext == true ]]
then
  extension=""
else
  extension=."${input##*.}"
fi
origin_dir=`dirname "$input"`

# Create work directories in the system temp folder
tempdir=`echo $TMPDIR`
workdir="$tempdir$number"_tesseract
finaldir=$workdir
mkdir $workdir

# Check for language. Easy to forget to specify.
# Needs some error checking
if [[ $lang == '' ]]
then
    read -p 'No language was specified. Hit enter to use English or supply the 3-letter language code: ' langInput
    if [[ $langInput == '' ]]
    then
        lang='eng'
    else
        lang=$langInput
    fi
fi

# OCR and save to PDF
# Convert to correctly sized png which tesseract leaves alone when making PDF
# Testing: don't understand why I'm converting to png here
for i in "$origin_dir"/"$firstchar"*"$extension"
do
  dpi=`get_dpi "$i"`
  dpth=`get_depth "$i"`
  output=`basename "$i"`
#  output=${output%.*}
  cp "$i" "$workdir/$output"
#  magick "$i" -units PixelsPerInch -density $dpi +repage -define png:compression-filter=1 -define png:compression-level=3 -define png:compression-strategy=0 "$workdir/$output.png"
done

# Enlarge if the dpi is too small for a good tesseract reading
# A bit arbitrary to use 300 dpi as minimum. Should estimate better.
# Make a PDF of original and combine with no-image PDF from tesseract.
#for i in "$workdir/"*".png"
counter=0
itemTotal=`ls "$workdir/"*"$extension" | wc -l`
for i in "$workdir/"*"$extension"
do
  # Spit out a little output for user feedback
  counter=$(( counter + 1 ))
  filename=`basename "$i"`
  echo -en "\r\033eProcessing file" $counter "of" $itemTotal "files..."
  if [[ $dpth -eq 1 ]]
    then
      ccitt=" -monochrome -compress Group4 -quality 100 "
    else
      ccitt=""
  fi
  if [[ $dpi -lt 300 ]]
	then
	  # Create directories for enlarging if needed after files have been grabbed
	  if [ ! -d "$workdir/big" ]
	  then
	    mkdir $workdir/big
	    mkdir $workdir/final
	  fi
      enlarge=`get_enlargement "$dpi"`
	  finaldir="$workdir/final"
	  # Create enlarged file for tesseract
	  magick "$i" $tiff -resize $enlarge "$workdir/big/$filename"
	  # Create PDF at original size
	  #magick "$i" $tiff  "$workdir/$filename.pdf"
	  img2pdf "$i" -o  "$workdir/$filename.pdf"
	  # Create text-only PDF with tesseract
	  tesseract -l $lang -c textonly_pdf=1 "$workdir/big/$filename" "$workdir/big/$filename" pdf quiet
	  # Combine two PDF files for final version
	  qpdf "$workdir/$filename.pdf" --overlay "$workdir/big/$filename.pdf" -- "$finaldir/$filename.pdf"
	else
	  tesseract -l $lang "$workdir/$filename" "$finaldir/$filename" pdf quiet
	fi
done

echo "done."

# Sleeping to avoid some unexpected terminations
sleep 5 && qpdf --empty --pages "$finaldir/"*.pdf -- "$origin_dir/$finalname"

endTime=`date +%s`
elapsedTime=$(( $endTime - $startTime ))
timeMessage="Elapsed time: $(( ${elapsedTime} / 3600 ))h $(( (${elapsedTime} / 60) % 60 ))m $(( ${elapsedTime} % 60 ))s"
terminal-notifier -message "Your OCR is complete. $timeMessage"  -title "Yay!" -sound default
