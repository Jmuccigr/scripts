#!/bin/bash

# A script to compare tags in Obsidian vault files with a Zotero library.
# Files are named in the following way: @citationKey.md
# Files that don't match the pattern of @something.md are ignored.

# Identify the location for the files and set some variables
me=$USER
vault="/Users/"$me"/Library/Mobile Documents/iCloud~md~obsidian/Documents/notes/Zotero"
zoterojson="/Users/"$me"/Documents/github/local/miscellaneous/My Library for backup.json"
checklist=""
missinglist=""
tagcomp=""
vaultlist=""

# First create a json file for all the vault files, including only the vital info

echo -e "Reading the"$vaultct" vault files..."

# Instead of comparing all of them, just worry about the ones from the Obsidian plugin.
# Do this by looking for files that contain a string unique to the plugin: "literaturenote"
# The zot2obsidian script will catch the other files.
vaultfiles=`grep -l "literaturenote" "$vault"/@*.md`
vaultct=`echo -e "$vaultfiles" | wc -l`

echo -e "There are"$vaultct "files to check the tags for."

while IFS= read -r line; do
  vaulttext=`cat "$line"`
  lastline=`echo -e "$vaulttext" | grep -n -e "^---" | sed -n '2p' | sed 's/:.*//'`
  lastline=$((lastline - 1))
  yamltext=`echo -e "$vaulttext" | head -n "$lastline" | yq -p yaml -o json` || echo "$line"
  vaultlist="$vaultlist $yamltext"
done <<< "$vaultfiles"
vaultarray=`echo "$vaultlist" | jq -s . |  jq -c 'pick(.[].citekey, .[].tags)' | sed 's/\:null\}/\:\[\]\}/g'`
vaultlist=`echo "$vaultarray" | jq '.[]'`
vaultkeys=`echo "$vaultlist" | jq -r '.citekey'`
vaultct=`echo "$vaultkeys" | wc -l`
vaulttenth=$((vaultct / 10 ))

echo "Done reading vault files..."

# Now deal with the Zotero entries

zoterolist=`cat "$zoterojson" | jq '.items[]' | jq -c 'pick(.citationKey, .tags) | del(.tags[].type)'`

echo "Done reading Zotero file..."

# Now loop through and compare tags
# Use a counter to eliminate the need to use a slower jq "select" for the zotero list
i=0
ct=0
echo -n "Progress: 0%..."
for e in $vaultkeys; do
  if [[ ! `echo "$zoterolist" | grep "$e"` ]]; then
    missingcount=$(( missingcount + 1 ))
    missinglist="$missinglist@$e\n"
    i=$(( i + 1 ))
  else
    zoterotags=`echo "$zoterolist" | jq "select(.citationKey == \"$e\") | .tags[].tag " | sed 's/ /_/g' | sort -f`
    vaulttags=`echo "$vaultarray" | jq ".[$i].tags[]" | sort -f`
    i=$(( i + 1 ))
    m=$((i % vaulttenth))
    [[ $m == 0 ]] && echo -n "$((i * 100 / vaultct))%..."
    if [ "$vaulttags" != "$zoterotags" ]; then
      tagcomp="$tagcomp$e\nvault tags\n>\n$vaulttags\n<\nzotero tags\n>\n$zoterotags\n<\n"
      ct=$((ct + 1))
      checklist="$checklist@$e\n"
    fi
  fi
done
echo -e "\n"

# Finally report what was found
if [[ $missinglist != "" ]]; then
  missinglist=`echo "$missinglist" | sort`
  echo -e ""
  echo -e "The following are not present in Zotero:"
  echo -e "$missinglist"
fi
echo -e "There are" $ct "files where the tags do not match Zotero."
[[ $ct -ne 0 ]] && checklist=`echo "$checklist" | sort`; echo -e "$checklist"
if [[ $tagcomp != "" ]]; then
  echo -e ""
  echo -e "The following tag groups don't match:"
  echo -e "$tagcomp"
fi
