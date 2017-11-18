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
bgclean=false
deg=0
deskew=''
despeckle=''
layout=''
outputFormat=' -png '
rotate=false
twice=false
number=$RANDOM
number="0000$number"
number=${number: -5}
output="$number"_output
unpaperOptions=' --no-border-align ' # Supposed to be the default, but isn't

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
      echo "-h, --help    Show brief help."
      echo "-rotate <deg> Rotate input file stated degrees clockwise."
      echo "-single       Process input file with unpaper at one page per image."
      echo "              This will eliminate the right-hand page if there are two."
      echo "-double       Process input file with unpaper at two pages per image."
      echo "-twice        Process twice with unpaper (also sets -double)."
      echo "-deskew       Applies imagemagick's deskew command at 40% & trims the result."
      echo "-despeckle    Applies imagemagick's despeckle command."
      echo ""
      echo "              deskew and despeckle are always applied last."
      echo ""
      echo "-bgclean      Removes gray background color. Will also negatively affect images."
      echo "              This is always applied last."
      echo " "
      echo "If input file does not have PDF extension, all files in same directory with"
      echo "same extension and starting character will be processed."
      echo " "
      echo "Clean up scans of text-only articles. Careful use might work with images too."
      echo " "
      echo "Convert PDF to constituent image files and then process them."
      echo "Use unpaper to separate pages, if desired, and imagemagick to clean up"
      echo "and deskew. New files are saved in directories within the input file's home directory."
      echo " "
      echo "Check quality of output files before proceeding to OCR."
      exit 0
      ;;
    -rotate)
      shift
      deg=$1
      rotate=true
      shift
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
    -bgclean)
      bgclean=true
      unpaperOptions="$unpaperOptions --no-grayfilter --no-noisefilter "
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
  echo -e "\a"File "$1" does not appear to exist or has no content! Exiting...
  echo ''
  exit 0
fi

# Throw warning when nothing to be done
if [[ $input_extension != 'pdf' && $layout == '' && $deskew == '' && $despeckle == '' && $bgclean == false && $rotate == false ]]
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
    echo -e "\a    Generally speaking deskewing a two-page layout has minimal effect."
    echo -e "    deskew will therefore be applied after unpaper."
    echo ''
fi

# Use file's directory for temporary files
dir=`dirname "$1"`

# Set up working directories
rotatedir="rotated_$number"
convertdir="convert_$number"
unpaperdir="unpaper_$number"
unpaper2dir="unpaper2_$number"
cleandir="clean_$number"
bgcleandir="bgclean_$number"

# Each process creates its own destination directory and leaves it as the 
# origin directory for the next process

# Split out images from PDF if necessary
if [[ $input_extension == 'pdf' ]]
then
  mkdir "$dir/$convertdir"
  pdfimages $outputFormat "$1" "$dir/$convertdir/$output"
  # Get filetype that was output
  input=`ls "$dir/$convertdir/$output"* | head -n 1`
  extension="${input##*.}"
  origin_dir="$dir/$convertdir"
#  workingdir="$convertdir"
  search_string=("$origin_dir/$output-"*)
else
  extension=$input_extension
  origin_dir="$dir"
#  origin_dir=`echo "$dir" | sed "s/ /\\\\\ /g"`
#  workingdir=''
  firstchar=`basename "$1"`
  firstchar=${firstchar:0:1}
  search_string_prefix="$origin_dir/$firstchar"
  search_string_suffix=".$input_extension"
  search_string=("$origin_dir/$firstchar"*".$input_extension")
fi

# rotate
if [[ $rotate == true ]]
then
  # echo "${search_string[@]}"
  extension='png'
  mkdir "$dir/$rotatedir"
#  workingdir="$cleandir"
#   if [[ $input_extension == 'pdf' ]]
#   then
#     search_string="$origin_dir/$output-"*
#   else
#     search_string="$origin_dir/$firstchar"*".$input_extension"
#   fi
  convert -rotate $deg -define png:compression-filter=1 -define png:compression-level=3 -define png:compression-strategy=0 +repage "${search_string[@]}" "$dir/$rotatedir/$output"-%03d.$extension 1>/dev/null
  echo string: $deskew $despeckle "${search_string[@]}" "$dir/$rotatedir/$output"-%03d.$extension 1>/dev/null
  origin_dir="$dir/$rotatedir"
  search_string=("$origin_dir/$output-"*)
fi

# First use unpaper on scans with 2 pages per image or if requested
# Running it twice sometimes improves output
if [[ $layout != '' ]]
then
  mkdir "$dir/$unpaperdir/"
  if [[ $twice == true ]]
  then
    mkdir "$dir/$unpaper2dir/"
  fi
  # Need a workaround for unpaper not starting counting at 00, but 01
  j=0
  for i in "${search_string[@]}"
  do
    k="00$j"
	l=${k: -3}
	input_name=`basename "$i"`
	input_name=${input_name%%.*}
	if [[ $twice = true ]]
	then
	  unpaper $unpaperOptions -l $layout -op 1 "$i" "$dir/$unpaper2dir/$input_name".pgm
	  unpaper $unpaperOptions -l $layout -op 2 "$dir/$unpaper2dir/$input_name".pgm "$dir/$unpaperdir/$output-$l-%03d".pgm
	else
	  if [[ $op -eq 1 ]]
	  then
	    # Keep the same file name when image has a single page on it
        unpaper $unpaperOptions -l $layout -op $op "$i" "$dir/$unpaperdir/$output-$l".pgm
      else
        unpaper $unpaperOptions -l $layout -op $op "$i" "$dir/$unpaperdir/$output-$l"-%03d.pgm
	  fi
	fi
    ((j++))
  done
  if [[ $twice ]]
  then
    origin_dir="$dir/$unpaperdir"
  else
    origin_dir="$dir/$unpaper2dir"
  fi
  search_string="$origin_dir/$output-"*".pgm"
fi

# despeckle and deskew
if [[ $deskew != '' || $despeckle != '' ]]
then
  # echo "${search_string[@]}"
  extension='png'
  mkdir "$dir/$cleandir"
#  workingdir="$cleandir"
#   if [[ $input_extension == 'pdf' ]]
#   then
#     search_string="$origin_dir/$output-"*
#   else
#     search_string="$origin_dir/$firstchar"*".$input_extension"
#   fi
  convert $deskew $despeckle -define png:compression-filter=1 -define png:compression-level=3 -define png:compression-strategy=0 +repage "${search_string[@]}" "$dir/$cleandir/$output"-%03d.$extension 1>/dev/null
  echo string: $deskew $despeckle "${search_string[@]}" "$dir/$cleandir/$output"-%03d.$extension 1>/dev/null
  origin_dir="$dir/$cleandir"
  search_string=("$origin_dir/$output-"*)
fi

# Finally can clean the background
if [[ $bgclean == true ]]
then
  # echo 'bg search: '"$search_string"
  extension='png'
  mkdir "$dir/$bgcleandir"
#   origin_dir=$( cd "$(dirname "$origin_dir")" ; pwd -P )
#   echo search_string: "$search_string"
#   for i in `eval ls "$search_string"`; do echo $i; done
#   exit 0
for i in "${search_string[@]}"
  do
    # echo "$i"
    k="00$j"
    l=${k: -3}
    # echo "$dir/$bgcleandir/$output"-$l.$extension
    convert "$i" -colorspace gray -contrast-stretch 5%,90% \( +clone -canny 0x1+10%+30% -morphology Close:3 Disk:2.5 \) -compose divide_src -composite -define png:compression-filter=1 -define png:compression-level=3 -define png:compression-strategy=0 +repage "$dir/$bgcleandir/$output"-$l.$extension 1>/dev/null
  #  convert "$search_string" \( +clone -blur 3 -level 10%,75% -negate -morphology dilate disk:2.5 \) -compose divide_src -composite "$dir/$bgcleandir/$output"-%03d.$extension 1>/dev/null
    ((j++))
  done
  # convert "$search_string" \( +clone -canny 0x1+10%+30% -morphology Close Disk:2.5 \) -compose divide_src -composite "$dir/$bgcleandir/$output"-$l.$extension 1>/dev/null
  origin_dir="$dir/$bgcleandir"
  search_string="$origin_dir/$output-"*
fi
