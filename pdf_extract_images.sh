#!/bin/bash
#
# Extract and clean up PDFs of articles, text-only
#
# 1. Extract images from PDF
# 2. Use unpaper to split the pages and do its cleanup
# 3. Use Fred's textcleaner?
# 4. Stop here to manually check the files.

s=''
j=0
deskew=''
despeckle=''
layout=''
outputFormat=' -png '
twice=false

# set up functions to report Usage and Usage with Description
PROGNAME=`type convert | awk '{print $3}'`  # search for convert executable on path
PROGDIR=`dirname $PROGNAME`                 # extract directory of program
PROGNAME=`basename $PROGNAME`               # base name of program

# Read flags
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

# Make sure file exists
if [[ ! -s "$1" ]]
then
  echo ''
  echo -e "\a"File "$1" does not appear to exist! Exiting...
  echo ''
  exit 0
fi

# Use file's directory for temporary files
dir=`dirname "$1"`

number=$RANDOM
number="00$number"
number=${number: -5}
output="$number"_output
convertdir="convert_$number"
unpaperdir="unpaper_$number"
unpaper2dir="unpaper2_$number"
unpaper3dir="unpaper3_$number"
cleandir="clean_$number"
workingdir=$convertdir

# Create images from the pdf, using existing dpi
# 
# s=$(pdfimages -list "$input" | grep '%' | head -n 1)
# if [[ $s == '' ]]
# then
#   echo "Can't determine the dpi of the images. Using 72."
#   dpi=72
# else 
#   a=( $s )
#   INV=' '
#   dpi=${a[12]}
# fi
# 
#convert -density $dpi -depth 8 "$1" $deskew $despeckle "$dir/$convertdir/$output%03d.pgm"

mkdir "$dir/$convertdir"
pdfimages $outputFormat "$1" "$dir/$convertdir/$output"

input=`ls "$dir/$convertdir/$output"* | head -n 1`
extension="${input##*.}"

if [[ $deskew != '' || $despeckle != '' ]]
then
  mkdir "$dir/$cleandir"
  workingdir=$cleandir
  convert $deskew $despeckle "$dir/$convertdir/$output-"* "$dir/$cleandir/$output-%03d.$extension" 1>/dev/null
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
  for i in `ls "$dir/$convertdir/"`
  do
	k="00$j"
	l=${k: -3}
	if [[ $twice = true ]]
	then
	  unpaper -l $layout -op 1 "$dir/$workingdir/$i" "$dir/$unpaper2dir/$i"
	  unpaper -l $layout -op 2 "$dir/$unpaper2dir/$i" "$dir/$unpaperdir/$output-$l%02d.$extension"
	else
	if [[ $op -eq 1 ]]
	then
	  # Keep the same file name when image has a single page on it
	  unpaper -l $layout -op $op "$dir/$workingdir/$i" "$dir/$unpaperdir/$output-$l.$extension"
	else
	  unpaper -l $layout -op $op "$dir/$workingdir/$i" "$dir/$unpaperdir/$output$l%02d.pgm"
	fi
	fi
    ((j++))
  done
fi
