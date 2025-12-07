#!/bin/bash

# A script to generate minimal Obsidian files from a Zotero library.
# Files are named in the following way: @citationKey.md
# Files that don't match the pattern of @something.md are ignored.


# Identify the location for the files and set some variables
datestring=`date +%Y%m%d.%H%M%S`
tmpdir=`echo $TMPDIR`
me=$USER
vault="/Users/"$me"/Library/Mobile Documents/iCloud~md~obsidian/Documents/notes/Zotero"
finaldir=$tmpdir"split"$datestring
srcFile="/Users/"$me"/Documents/github/local/miscellaneous/My Library for backup.json"

useTags=false
useDate=false
overwrite=false
quiet=false

maxFile=""
orphans=""
zlist=""
ctEdited=0
ctNew=0
ctNoFile=0
ctOrphan=0
ctSame=0
ctSimilar=0
ctZero=0
maxDiff=0

# Read flags
#
while test $# -gt 0; do
  case "$1" in
    -h|--help)
      echo "$PROGNAME [options]"
      echo ""
      echo "Convert Zotero json output for Obsidian usage. Assumes file in Downloads folder."
      echo "Will convert all the items in the absence of a tag or date selection."
      echo "Files should be named \"@citationKey.md\". All other files will be ignored."
      echo ""
      echo "options:"
      echo "-h, --help       show this brief help"
      echo "-o, --overwrite  auto-overwrite the Obsidian file if difference is minimal"
      echo "-q, --quiet      don't show the Obsidian filename if difference is minimal"
      echo "-t, --tags       select items by tag text"
      echo "-d, --date       select items by date of last modification. Required format: 'YYYY-MM-DD'."
      echo ""
      echo "You can filter on only one item, and if a date filter is selected, it will be used and"
      echo "no tag filter will be applied, even if given."
      exit 0
      ;;
    -q|--quiet)
      quiet=true
      shift
      ;;
    -o|--overwrite)
      echo "Overwriting the vault files is not undo-able, though you can always regenerate them from"
      echo "Zotero via the Obsidian plugin."
      echo ""
      read -t 10 -p "Are you sure you want to overwrite? (y/N) " overwriteReply
      if [[ $overwriteReply == "y" ]]
      then
        overwrite=true
        quiet=true
      fi
      shift
      ;;
    -t|--tags)
      useTags=true
      shift
      tagText=$1
      shift
      ;;
    -d|--date)
      useDate=true
      shift
      dateText=$1
      shift
      ;;
   *)
      break
      ;;
  esac
done

# Check for the Zotero library file in the location identified above

[ ! -f "$srcFile" ] && (echo "$srcFile does not exist. Quitting..."; exit 1)

if $useDate
then
  dateText=`echo $dateText | sed -E 's/.*([0-9]{4}-[0-9]{2}-[0-9]{2}).*/\1/g'`
  if [[ ${#dateText} -ne 10 ]]
  then
    echo -e "No valid date string found (YYYY-MM-DD). Exiting..."
    exit 1
  fi
  jsonfile=`jq -r '.items[] | select(.dateModified > ("'$dateText'"))' "$srcFile" | jq -s '.'`
elif $useTags
then
  jsonfile=`jq -r '.items[] | select(.tags[].tag | contains ("'$tagText'"))' "$srcFile"  | jq -s 'unique'?`
else
  echo "No filter applied. This might take a little bit..."
  jsonfile=`jq -r '.items[]' "$srcFile" | jq -s 'unique'`
  zlist=`echo "$jsonfile" | jq -r .[].citationKey | sed 's/$/\.md/g'`
fi

zoterojson=`echo "$jsonfile" | jq -c ' pick(.[].title, .[].tags[].tag, .[].citationKey)'` || exit 1
zotct=`echo "$zoterojson" | jq '.[].citationKey' | wc -l`
if [[ $zotct -eq 0 ]]; then
  echo "There are no entries that meet the criteria. Quitting..."
  exit 0
else
  echo "There are" $zotct "entries that meet the criteria."
fi

# TODO: figure out the last regex to avoid the repetition

yamlFile=`echo $zoterojson | yq -p json -o yaml ' (.. | select(key == "title") ) style="double"' | sed 's/citationKey:/citekey:/' | perl -pe 's/^[^a-z]+//g' | perl -pe 's/^tag: /  - /g' | perl -pe 's/^(title:)/---\n\1/' | perl -pe 's/(^  - .+?) /\1\2_/g' | perl -pe 's/(^  - .+?) /\1\2_/g' | perl -pe 's/(^  - .+?) /\1\2_/g' | perl -pe 's/(^  - .+?) /\1\2_/g' | perl -pe 's/(^  - .+?) /\1\2_/g' | perl -pe 's/(^  - .+?) /\1\2_/g' | perl -pe 's/(^  - .+?) /\1\2_/g'` || exit 1

mkdir "$finaldir" &2>/dev/null || exit 1
sleep 1
echo "$yamlFile" | split -a 4 -d -p "^\-\-\-" - "$finaldir/items" || exit 1
sleep 1

for f in $finaldir/items*; do
  cat $f > $f".txt"
  echo -e "---" >> $f".txt"
  filename=`grep citekey "$f" | sed 's/.* //'`
  cp $f".txt" "$finaldir/@$filename.md"
done

# Sanity check on output
ctTxt=`ls $finaldir/*.txt | wc -l`
ctMd=`ls $finaldir/*.md | grep -c '^'`
if [[ $ctTxt -ne $ctMd ]] || [[ $ctTxt -eq 0 ]]; then
  echo ""
  echo "Uh-oh, something went wrong there. Have a look."
  echo "The number of .txt files generated was " $ctTxt " and .md files was $ctMd."
  open "$finaldir/"
  exit 1
fi

# Everything looks ok, so continue
echo -e ""
echo "Export processed successfully! Now comparing to the vault..."
echo -e ""

# Automate some of the comparisons:
#
# Delete the intermediate files which have names like "item..."
find $finaldir -name "item*" -delete

# Check for files in the vault that don't have a match in Zotero
# Get list of Zotero items and massage their names to match the list from the vault
if [[ $zlist == "" ]]; then
  zlist=`grep -o "citationKey.*\"" "$srcFile" | perl -pe 's/.*\: \"(.+)\"/\1.md/g'`
fi

# Get all files in the vault 
mdlist=`ls "$vault"/@*.md | perl -pe 's/^.+@(.+)/\1/g'`

echo -e "Checking for orphaned files in the vault..."
while IFS= read -r mdfile; do
  if [[ ! $zlist =~ $"$mdfile" ]]; then
    # Leave notes that don't match a Zotero entry (orphans).
    # These will have "literaturevalue" in yaml.
    if grep -q "literaturenote" "$vault/@$mdfile"; then
      ctOrphan=$(( ctOrphan + 1 ))
      orphans="@"$mdfile"\n"$orphans
    else
      ctNoFile=$(( ctNoFile + 1 ))
      rm "$vault/@"$mdfile
    fi
  fi
done < <(printf %s "$mdlist")

echo -e "Comparing the vault files with the Zotero export..."

# If the file exists in the vault and is big enough (1.5k?), then flag the new file by moving
# it to a new folder(?)
for zf in $finaldir/*.md; do
  fn=`basename $zf`
  if [ ! -f "$vault/$fn" ]; then
    ctNew=$(( ctNew + 1 ))
    newfiles=$fn"\n"$newfiles
    mv "$finaldir/$fn" "$vault"
  else
    # Don't even process files when they've been exported to the vault via the plugin
    # Check for yaml line found only in plugin output
    if grep -q "literaturenote" "$vault/$fn"; then
      ctEdited=$(( ctEdited + 1 ))
      rm "$zf"
    else
      # Delete the file if it's the same as the vault version
      if diff -q "$zf" "$vault/$fn" 1>2 ; then
        ctSame=$(( ctSame + 1 ))
        rm "$zf"
      else
        # Look at size of the difference
        sizeDiff=$((`stat -f%z "$vault/$fn"` - `stat -f%z "$zf"`))
        sizeDiff="${sizeDiff/#-}"
        # Keep track of the biggest difference
        if [[ $sizeDiff -gt $maxDiff ]]; then
          maxDiff=$sizeDiff
          maxFile=$fn
        fi
        # If the size of the difference is 0, it's probably just a minor change, so overwrite the vault
        # Use applescript to remove the existing file to try to avoid dupication problems?
        if [[ $sizeDiff -eq 0 ]]; then
          ctZero=$(( ctZero + 1 ))
          mv "$zf" "$vault/"
        else
          # If the vault file is sizeable, it may be hand-edited, so track it
          if [ `stat -f%z "$vault/$fn"` -gt 600 ]; then
            # If the difference is small, overwrite it, if instructed to
            if [[ $sizeDiff -lt 100 ]]; then
              ctSimilar=$(( ctSimilar + 1 ))
              if $overwrite ; then mv "$zf" "$vault/$fn"; fi
              if [ $quiet == false ]; then echo "$fn is different, and probably can be copied over. Change in file size: " $sizeDiff; fi
            else
              # Otherwise the difference is not small, so don't overwrite
              echo "$fn is different, but the vault version may be fuller. " `stat -f%z "$vault/$fn"` "Change in file size: " $sizeDiff
            fi
          else
            # If the vault file isn't big and so generated by this script, overwrite if told to
            ctSimilar=$(( ctSimilar + 1 ))
            if $overwrite; then
              mv "$zf" "$vault/"
            else
              if [ $quiet == false ]; then echo "$fn is different, and probably can be copied over. Change in file size: " $sizeDiff; fi
            fi
          fi
        fi
      fi
    fi
  fi
done

# Report on the results
echo ""
if [[ $ctNew -gt 0 ]]; then
  pref=$ctNew
  suf=" and moved over:\n$newfiles"
else
  pref="No"
  suf="."
fi
echo -e $pref "Zotero entries were missing from the vault"$suf

if [[ $ctNoFile -gt 0 ]]; then echo $ctNoFile "files in the vault did not show up in the Zotero export and were not generated by the plugin, and so were deleted.";fi

if [[ $ctZero -gt 0 ]]; then echo $ctZero "files had no size difference and were overwritten in the vault.";fi

if [[ $ctEdited -gt 0 ]]; then echo $ctEdited "files in the vault had been exported from Zotero, so the new copies were ignored and deleted.";fi

if [[ $ctSame -gt 0 ]]; then echo $ctSame "files were the same in both places and were ignored.";fi

if [[ $ctOrphan -gt 0 ]]; then echo -e $ctOrphan "files in the vault did not match Zotero but were generated by the plugin. Check on them:\n$orphans";fi

if [[ $ctSimilar -gt 0 ]]; then
  case $overwrite in
    (true)    finish=" and overwritten in the vault.";;
    (false)   finish=".";;
  esac
  echo $ctSimilar "files were similar in both places"$finish
  echo "    The maximum size difference between files was "$maxDiff": "$maxFile"."
fi

if [[ `ls $finaldir | wc -l` -gt 0 ]]; then
  open "$finaldir/"
else
  echo ""
  echo "There are no remaining files to worry about."
fi
