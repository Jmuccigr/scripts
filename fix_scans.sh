#!/bin/bash
#
# Extract and clean up scans of articles, text-only
#
# 1. Extract images from PDF, if necessary
# 2. Deskew and/or despeckle with imagemagick
# 3. Use unpaper to split the pages and do its cleanup
# 4. Add Fred's textcleaner?
# 5. Stop here to manually check the files.

s=''
j=0
deskew=''
despeckle=''
layout=''
outputFormat=' -png '
twice=false
number=$RANDOM
number="00$number"
number=${number: -5}
output="$number"_output
unpaperOptions="--no-border-align" # Supposed to be the default, but isn't

# set up functions to report Usage and Usage with Description
PROGNAME=`type convert | awk '{print $3}'`  # search for convert executable on path
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
      echo "$PROGNAME [options] input_file"
      echo " "
      echo "options:"
      echo "-h, --help    Show brief help"
      echo "-double       Process input file with unpaper at two pages per image"
      echo "-single       Process input file with unpaper at one page per image."
      echo "              This will eliminate the right-hand page if there are two."
      echo "-twice        Process twice with unpaper (also sets -double)"
      echo "-deskew       Applies imagemagick's deskew command at 40%"
      echo "-despeckle    Applies imagemagick's despeckle command"
      echo " "
      echo "Convert PDF to constituent image files and process them"
      echo "with unpaper to separate pages, if desired. New files are"
      echo "saved in directories within the input file's home directory."
      echo " "
      echo "Check quality of output files before proceeding to OCR."
      exit 0
      ;;
    -double)
      if [[ "$twice" == true ]]
      then
        echo "No need to set -double when using -twice"
      fi
      op=2
      layout='double'
      outputFormat=''
      shift
      ;;
    -single)
      op=1
      layout='single'
      outputFormat=''
      shift
      ;;
    -twice)
      twice=true
      shift
      if [[ $layout != '' ]]
      then
        echo "No need to set -double when using -twice"
      fi
      op=2
      layout='double'
      outputFormat=''
      ;;
    -deskew)
      deskew=' -deskew 40% '
      shift
      ;;
    -despeckle)
      despeckle=' -despeckle '
      shift
      ;;
    *)
      break
      ;;
  esac
done

# Remaining input should be the filename
input="$1"
input_extension="${1##*.}"

# Make sure file exists
if [[ ! -s "$1" ]]
then
  echo ''
  echo -e "\a"File "$1" does not appear to exist! Exiting...
  echo ''
  exit 0
fi

# Throw warning when nothing to be done
if [[ $input_extension != 'pdf' && $layout == '' && $deskew == '' && $despeckle == '' ]]
then
    echo ''
    echo  -e "\a    Oops! Nothing will happen to non-PDF files unless some processing is specified."
    echo ''
    exit 0
fi

# Throw warning when deskew and double are both applied
if [[ $deskew != '' && $layout == 'double' ]]
then
    echo ''
    echo  -e "\a    Generally speaking deskewing a two-page layout has minimal effect."
    echo ''
fi

# Use file's directory for temporary files
dir=`dirname "$1"`

# Set up working directories
convertdir="convert_$number"
unpaperdir="unpaper_$number"
unpaper2dir="unpaper2_$number"
unpaper3dir="unpaper3_$number"
cleandir="clean_$number"

if [[ $input_extension == 'pdf' ]]
then
    mkdir "$dir/$convertdir"
    pdfimages $outputFormat "$1" "$dir/$convertdir/$output"
    # Get filetype that was output
    input=`ls "$dir/$convertdir/$output"* | head -n 1`
    extension="${input##*.}"
    origin_dir="$dir/$convertdir"
    workingdir="$convertdir"
else
    extension=$input_extension
    origin_dir="$dir"
    firstchar=`basename "$1"`
    firstchar=${firstchar:0:1}
    workingdir=''
fi

if [[ $deskew != '' || $despeckle != '' ]]
then
  extension='png'
  mkdir "$dir/$cleandir"
  workingdir="$cleandir"
  if [[ $input_extension == 'pdf' ]]
  then
    search_string="$origin_dir/$output-"*
  else
    search_string="$origin_dir/$firstchar"*".$input_extension"
  fi
  convert $deskew $despeckle "$search_string" "$dir/$cleandir/$output"-%03d.$extension 1>/dev/null
fi

# Use unpaper on scans with 2 pages per image or if requested
# Running it twice sometimes improves output
if [[ $layout != '' ]]
then
  mkdir "$dir/$unpaperdir/"
  if [[ $twice = true ]]
  then
    mkdir "$dir/$unpaper2dir/"
  fi

  # Need a workaround for unpaper not starting counting at 00, but 01
  for i in "$dir"/"$workingdir"/*."$extension"
  do
    k="00$j"
	l=${k: -3}
	input_name=`basename "$i"`
	input_name=${input_name%%.*}
	if [[ $twice = true ]]
	then
	  unpaper "$unpaperOptions" -l $layout -op 1 "$i" "$dir/$unpaper2dir/$input_name".pgm
	  unpaper "$unpaperOptions" -l $layout -op 2 "$dir/$unpaper2dir/$input_name".pgm "$dir/$unpaperdir/$output-$l-%02d".pgm
	else
	  if [[ $op -eq 1 ]]
	  then
	    # Keep the same file name when image has a single page on it
        unpaper -l $layout -op $op "$i" "$dir/$unpaperdir/$output-$l".pgm
      else
        unpaper -l $layout -op $op "$i" "$dir/$unpaperdir/$output"-"$l"-%02d.pgm
	  fi
	fi
    ((j++))
  done
fi
