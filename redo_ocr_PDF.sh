#!/bin/sh

datestring=`date +%Y-%m-%d_%H.%M.%S`
dir_path=$(dirname $0)
# Get length so final finalname is not too long
ldate=`echo ${#datestring}`
maxl=`expr 255 - $ldate`
tmpdir=`echo ${TMPDIR:-/tmp}`
keepfirst=false
lang=""

# Read flags
# Provide help if no argument
if [[ $# == 0 ]]
then
    set -- "-h"
fi

while test $# -gt 0; do
  case "$1" in
    -h|--help)
      echo ""
      echo "This script will remove existing text in a PDF and then perform OCR and"
      echo "add that text to it the original."
      echo ""
      echo "The original file is left alone and a new file is created with a datestamped name."
      echo ""
      echo "options:"
      echo "-h, --help     Show this brief help."
      echo "-f, --first    Keep the first page of the original PDF."
      echo "-l language    Use this language for OCR (defaults to English)"
      echo "               Use one of tesserat's 3-letter codes for this"
      exit 0
      ;;
    -f|--first)
      shift
      first=true
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

input="$1"
input_extension="${1##*.}"

if [[ "$1" == "" ]]
then
  echo "\aYou must enter a filename."
  exit 0
fi

# Make sure file exists
if [[ ! -s "$input" ]]
then
  echo ''
  echo "\a"File \""$input"\" does not appear to exist or has no content! Exiting...
  echo ''
  exit 0
fi

# Make sure it's a PDF
if [[ $input_extension != 'pdf' ]]
then
  echo ''
  echo -e "\a"File "$input" does not appear to be a PDF. Exiting...
  echo ''
  exit 0
fi

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

# Get final output file name
final=`basename "$input"`
final=`echo ${final%.*}`
final=`echo ${final:0:$maxl}`
final="$final"_"$datestring".pdf
origdir=`dirname "$input"`
inputold="$input"

# If desired, remove the first page right away and save a little time
if [[ $first ]]
then
  input="$tmpdir"input_new.pdf
  qpdf "$inputold" --pages . 2-z -- "$input"
fi

# Strip metadata from input file
inputclean="$input"
# exiftool won't overwrite an existing file, so give output a unique name
input="$tmpdir"input_"$datestring".pdf
exiftool -q -q "$inputclean" -all='' -o "$input"

# strip text from the PDF
python3 "$dir_path/remove_PDF_text.py" "$input" "$tmpdir/no_text.pdf"
#gs -o "$tmpdir/no_text.pdf" -dFILTERTEXT -sDEVICE=pdfwrite "$input"

# Make sure output file exists
if [[ ! -s "$tmpdir/no_text.pdf" ]]
then
  echo ''
  echo "\a"Work file \""$input"\" does not appear to exist or has no content! Exiting...
  echo ''
  exit 0
fi

# ocr the original pdf, skipping optimization since we're throwing away the images
ocrmypdf --force-ocr --output-type pdf --optimize 0 -l $lang "$tmpdir/no_text.pdf" "$tmpdir/ocr_output.pdf"

#strip images from that result
gs -o "$tmpdir/textonly.pdf" -dFILTERIMAGE -dFILTERVECTOR -sDEVICE=pdfwrite "$tmpdir/ocr_output.pdf"

# overlay ocr text on file stripped of text
qpdf "$tmpdir/no_text.pdf" --overlay "$tmpdir/textonly.pdf" -- "$tmpdir/final.pdf"

# Restore the original metadata, if any
exiftool -tagsfromfile "$inputold" -title -author "$tmpdir/final.pdf"
# Remove some added metadata while we're at it
exiftool -Producer='' -XMPToolkit='' "$tmpdir/final.pdf"

# replace first page if required
if [ $first ]
then
  qpdf "$tmpdir/final.pdf" --pages "$inputold" 1 . 1-z -- "$origdir"/"$final"
else
  mv "$tmpdir/final.pdf" "$origdir"/"$final"
fi

if [[ $(uname) == 'Darwin' ]]
then
    terminal-notifier -message "Your OCR is complete." -title "Yay!" -sound default
fi
