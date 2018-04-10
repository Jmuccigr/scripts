#!/bin/bash
#
# Extract and clean up scans of articles, text-only
#
# 1. Extract images from PDF, if necessary
# 2. Use unpaper & process with imagemagick
# 3. Stop here to manually check the files

j=0
startpage=1
bgclean=false
deg=0
deskew=''
despeckle=''
layout=''
outputFormat=' -png '
extension='png'
rotate=false
twice=false
unpaperOptions=' --no-border-align ' # Supposed to be the default, but isn't
resize=false
sizegiven=false
enlarge=false
ccit=''
threshold='80%'
offset='15'
color='white'
side='north'
sidegiven=''
pngOpts=' '
#pngOpts=" -define png:compression-filter=1 -define png:compression-level=3 -define png:compression-strategy=0 "
number=$RANDOM
number="0000$number"
number=${number: -5}
output="$number"_output

# set up functions to report Usage and Usage with Description
PROGNAME=`type $0 | awk '{print $3}'`       # search for convert executable on path
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
      echo ""
      echo "Clean up scans of text-only articles. Careful use might work with images too."
      echo ""
      echo "options:"
      echo "-h, --help     Show this brief help."
      echo "-f <X>         First processed page of PDF will be X. Does nothing on non-PDF."
      echo "-ccit          Convert image to 1-bit."
      echo "-threshold <%> Percentage to apply to creating 1-bit images."
      echo "               Defaults to 80%."
      echo "-rotate <deg>  Rotate input file stated degrees clockwise."
      echo "-single        Process input file with unpaper at one page per image."
      echo "               This will eliminate the right-hand page if there are two."
      echo "-double        Process input file with unpaper at two pages per image."
      echo "-twice         Process twice with unpaper (also sets -double)."
      echo "-noclean       Do not let unpaper do its own cleaning."
      echo "-deskew        Applies imagemagick's deskew command at 40% & trims the result."
      echo "               Since images will now differ in size, resizing is turned on, too."
      echo "               See the resizing options below."
      echo "-skewy         Applies deskew twice for images that are heavily skewed."
      echo "               Also trims to remove large borders."
      echo "-despeckle     Applies imagemagick's despeckle command."
      echo "-bgclean       Removes gray background color. Negatively affects images."
      echo "-offset        Set the bgclean offset (default is 15)"
      echo "-enlarge       Enlarge final images so width and height are 10% larger than maximum."
      echo "               It is also set with any of the following options."
      echo "               Resizing is always applied last."
      echo "-color         Set the background color when resizing. Default is white."
      echo "               Surround numeric colors by quotation marks, e.g., \"#444\"."
      echo "-size          Create final files at given size. Format should be:"
      echo "               <width>x<height>, where width and height are integers."
      echo "-max           Create final files at maximum existing file dimensions."
      echo "-side <top|bottom|left|right|north|south|east|west|center>"
      echo "               Choose side to align image file with new size. Default is top/north."
      echo "-recenter      Center the printed area left-right in the final output."
      echo "-crush         Apply pngcrush to compress the final files. Can be lengthy."
      echo ""
      echo "If input file does not have PDF extension, all files in same directory with"
      echo "same extension and starting character will be processed."
      echo ""
      echo "Convert PDF to constituent image files and then process them."
      echo "Use unpaper to separate pages, if desired, and imagemagick to clean up"
      echo "and deskew. New files are saved in directories within the input file's home directory."
      echo ""
      echo "NB Check quality of output files before proceeding to OCR."
      exit 0
      ;;
    -f)
      shift
      startpage=$1
      re="^[0-9]+$"
	  if ! [[ $startpage =~ $re ]]
	  then
		echo -e "\a    First page is not a positive integer. Using 1." >&2
		startpage=1
	  fi
      shift
      ;;
    -ccit)
      ccit=" -threshold $threshold -alpha off -monochrome -compress Group4 -quality 100 "
      shift
      ;;
    -threshold)
      shift
      threshold=$1
      shift
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
#     outputFormat=''
      resize=true
      shift
      ;;
    -single)
      op=1
      layout='single'
#     outputFormat=''
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
#     outputFormat=''
      ;;
    -noclean)
      if [[ $bgclean == true || $offset != "15" ]]
      then
        echo "No need to set -noclean when using -bgclean or -offset"
	  else
	    unpaperOptions="$unpaperOptions --no-grayfilter --no-noisefilter "
      fi
      shift
      ;;
    -deskew)
      deskew=' -deskew 40% '
      resize=true
      shift
      ;;
    -skewy)
      deskew=' -deskew 40% -deskew 40% -fuzz 2% -trim '
      resize=true
      shift
      ;;
    -despeckle)
      despeckle=' -despeckle '
      shift
      ;;
    -bgclean)
      if [[ $offset != "15" ]]
      then
        echo "No need to set -bgclean when using -offset"
	  else
		bgclean=true
		unpaperOptions="$unpaperOptions --no-grayfilter --no-noisefilter "
	  fi
	  shift
      ;;
    -offset)
      shift
      offset=$1
      if [[ $bgclean == true ]]
      then
        echo "No need to set -bgclean when using -offset"
	  else
		bgclean=true
		unpaperOptions="$unpaperOptions --no-grayfilter --no-noisefilter "
	  fi
      if [[ $offset == "15" ]]
      then
        echo ''
        echo  -e "\a    offset already defaults to 15."
      fi
      shift
      ;;
    -resize)
      if [[ $resize == true ]]
      then
        echo ''
        echo -e "\a    No need to set -resize when using any option that alters image size"
	  else
        resize=true
	  fi
      shift
      ;;
    -size)
      resize=true
      sizegiven=true
      shift
      size=$1
      shift
      ;;
    -max)
      resize=true
      shift
      ;;
    -enlarge)
      resize=true
      enlarge=true
      shift
      ;;
    -color)
      resize=true
      shift
      color=$1
      shift
      ;;
    -side)
      resize=true
      shift
      sidegiven=$1
      shift
      ;;
    -recenter)
      recenter=true
      shift
      ;;
    -crush)
      crush=true
      echo ''
      echo  -e "\a    Crushing the files may take a while."
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
if [[ $input_extension != 'pdf' && $layout == '' && $deskew == '' && $despeckle == '' && $bgclean == false && $rotate == false && $resize == false && $crush == false && $ccit == false ]]
then
    echo ''
    echo  -e "\a    Oops! Nothing will happen to non-PDF files unless some processing is specified."
    echo ''
    exit 0
fi

# Throw warning when deskew and double are both applied
if [[ $deskew != '' && $layout == 'double' ]]
then
    echo ""
    echo -e "\a    Generally speaking deskewing a two-page layout has minimal effect."
    echo -e "    deskew will therefore be applied after unpaper."
fi

# Throw warning when offset but no bgclean
if [[ $offset != "15" && $bgclean == false ]]
then
    echo ""
    echo -e "\a"
    echo -e "    Setting offset without bgclean has no effect. Ignoring offset."
fi

# Use file's directory for temporary files
dir=`dirname "$1"`

# Set up working directories
ccitdir="ccit_$number"
rotatedir="rotated_$number"
convertdir="convert_$number"
unpaperdir="unpaper_$number"
unpaper2dir="unpaper2_$number"
cleandir="clean_$number"
bgcleandir="bgclean_$number"
recenterdir="recentered_$number"
resizedir="resized_$number"
crushdir="crushed_$number"

# Each process creates its own destination directory and leaves it as the
# origin directory for the next process

# Split out images from PDF if necessary
if [[ $input_extension == 'pdf' ]]
then
  # Check page count
  pdf_page_count=$(pdfinfo "$1" | grep Pages: | sed -E 's/^.* +//')
  if [[ $startpage > $pdf_page_count ]]
  then
    echo -e "\a    First page is greater than number of pages in PDF. Aborting."
    exit 1
  fi
  # Compare page count with image count in PDF
  image_pages=$(pdfimages -list "$1" | grep -E [0-9] | sed -E "s/([0-9]+).*/\1/g" | perl -pe "s/\n/ /g" | perl -pe "s/\s+/  /g")
  startpage_adj=`expr $startpage - 1`
  remaining_page_count=`expr $pdf_page_count - $startpage + 1`
  for i in `seq 0 $startpage_adj`
  do
	image_pages=$(echo "$image_pages" | perl -pe "s/ $i /  /g")
  done
  image_page_array=($image_pages)
  remaining_image_count=${#image_page_array[@]}
  if [[ $remaining_page_count != $remaining_image_count ]]
  then
	echo -e "\a    There are more images than pages. Check the output."
  fi
  mkdir "$dir/$convertdir"
  pdfimages -f $startpage $outputFormat "$1" "$dir/$convertdir/$output"
  # Get filetype that was output
  input=`ls "$dir/$convertdir/$output"* | head -n 1`
  extension="${input##*.}"
  origin_dir="$dir/$convertdir"
  search_string=("$origin_dir/$output-"*)
else
  extension=$input_extension
  origin_dir="$dir"
  firstchar=`basename "$1"`
  firstchar=${firstchar:0:1}
  search_string=("$origin_dir/$firstchar"*".$input_extension")
fi

# Throw warning when bitdepth is 1, but certain options were entered
bitdepth=$(identify -format "%k" "$search_string")
if [[ $bitdepth == '1' && $bgclean == true ]]
then
  echo -e "\a    Can't clean background on 1-bit images. Ignoring bgclean."
  bgclean=false
fi

if [[ $bitdepth == '1' || $ccit != "" ]]
then
  extension='tiff'
  ccit=" -threshold $threshold -alpha off -monochrome -compress Group4 -quality 100 "
  if [[ $crush == true ]]
  then
	echo -e "\a    1-bit images are not saved as png. Ignoring crush."
	crush=false
  fi
fi

# rotate
if [[ $rotate == true ]]
then
  # echo "${search_string[@]}"
  # extension='png'
  mkdir "$dir/$rotatedir"
  convert -rotate $deg $pngOpts +repage "${search_string[@]}" "$dir/$rotatedir/$output"-%03d.$extension 1>/dev/null
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
	  unpaper $unpaperOptions -l $layout -op 1 "$i" "$dir/$unpaper2dir/$input_name".pgm 1>/dev/null
	  unpaper $unpaperOptions -l $layout -op 2 "$dir/$unpaper2dir/$input_name".pgm "$dir/$unpaperdir/$output-$l-%03d".pgm 1>/dev/null
	else
	  if [[ $op -eq 1 ]]
	  then
	    # Keep the same file name when image has a single page on it
        unpaper $unpaperOptions -l $layout -op $op "$i" "$dir/$unpaperdir/$output-$l".pgm 1>/dev/null
      else
        unpaper $unpaperOptions -l $layout -op $op "$i" "$dir/$unpaperdir/$output-$l"-%03d.pgm 1>/dev/null
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
  search_string=("$origin_dir/$output-"*".pgm")
fi

# Now can clean the background
if [[ $bgclean == true ]]
then
  j=0
  # extension='png'
  mkdir "$dir/$bgcleandir"
  for i in "${search_string[@]}"
	do
	  k="00$j"
	  l=${k: -3}
	  convert "$i" -colorspace gray \( +clone -lat 30x30-$offset% -negate \) -compose divide_src -composite $pngOpts +repage "$dir/$bgcleandir/$output"-$l.$extension 1>/dev/null
	  ((j++))
	done
  origin_dir="$dir/$bgcleandir"
  search_string=("$origin_dir/$output-"*)
fi

# despeckle and deskew
if [[ $deskew != '' || $despeckle != '' ]]
then
  # echo "${search_string[@]}"
  # extension='png'
  mkdir "$dir/$cleandir"
  convert $deskew $despeckle $pngOpts -depth $bitdepth $ccit +repage "${search_string[@]}" "$dir/$cleandir/$output"-%03d.$extension 1>/dev/null
  origin_dir="$dir/$cleandir"
  search_string=("$origin_dir/$output-"*)
fi

# ccit
if [[ $ccit != '' ]]
then
  mkdir "$dir/$ccitdir"
  convert "${search_string[@]}" $ccit "$dir/$ccitdir/$output"-%03d.$extension 1>/dev/null
  origin_dir="$dir/$ccitdir"
  search_string=("$origin_dir/$output-"*)
fi

# Resize
if [[ $resize == true ]]
then
  if [[ $sidegiven == '' ]]
  then
    sidegiven='top'
  fi
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

  # Get max width and height
  filewxh=`convert -ping +repage -layers trim-bounds -delete 1--1 -format %P "${search_string[@]}" info:`
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
      if [[ $enlarge == true ]]
      then
        wd=$(( filew / 20 ))
        hd=$(( fileh / 20 ))
        w=$(( filew + wd * 2 ))
        h=$(( fileh + hd * 2 ))
      else # max must have been entered
        w=$filew
        h=$fileh
      fi
  fi

  # Create new directory & save converted files in it
  # Put existing file 5% down from the top of the background page by default
  # This will consistently treat final pages that are short.
  mkdir "$dir/$resizedir"
  j=0
  for i in "${search_string[@]}"
  do
    k="00$j"
    l=${k: -3}
    convert \( -size "$w"x"$h" -background "$color" xc: -write mpr:bgimage +delete \) mpr:bgimage -gravity $side -geometry +0+$hd "$i" -compose divide_dst -composite $pngOpts $ccit "$dir/$resizedir/$output-$l.$extension"
    ((j++))
  done
  origin_dir="$dir/$resizedir"
  search_string=("$origin_dir/$output-"*".$extension")
fi

# recenter
if [[ $recenter == true ]]
then
  mkdir "$dir/$recenterdir"
  j=0
  for i in "${search_string[@]}"
  do
    k="00$j"
    l=${k: -3}
	# Replace the edges to catch minor defects there, then capture printed area
	orig_dim=($(convert "$i" -shave 10x10 -bordercolor white -border 10x10 -blur 0,8 -normalize -fuzz 2% -trim -format "%W %H %X %Y %w" info:))
	w=${orig_dim[0]}
	h=${orig_dim[1]}
	x=${orig_dim[2]}
	y=${orig_dim[3]}
	new_w=${orig_dim[4]}
	x_dis=$(( (w - new_w) / 2))
	## Grab printed area and center it on white background
	convert \( -size "$w"x$h -background white xc: -write mpr:bgimage +delete \) mpr:bgimage \( -crop "$w"x$h+$x+$y "$i" \) -compose divide_dst -gravity northwest -geometry +$x_dis$y -composite $ccit "$dir/$recenterdir/$output-$l.$extension"
    ((j++))
  done
  origin_dir="$dir/$recenterdir"
  search_string=("$origin_dir/$output-"*)
fi

# pngcrush
if [[ $crush == true ]]
then
  extension='png'
  mkdir "$dir/$crushdir"
  j=0
  for i in "${search_string[@]}"
  do
    echo "$i"
    k="00$j"
    l=${k: -3}
    pngcrush "$i" "$dir/$crushdir/$output-$l.png" 1>/dev/null
    ((j++))
  done
  origin_dir="$dir/$crushdir"
  search_string=("$origin_dir/$output-"*)
fi
