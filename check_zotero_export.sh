#!/bin/bash

# Send email when Zotero library export file has 0 size

me=$(whoami)
dest="/Users/$me/Documents/github/local/miscellaneous"
f="My Library.json"

if [ ! -s "$dest/$f" ]
then
    echo 'Darn it!' | mail -s 'Zotero export failed' john
else
    # Commit it to github when it's changed
    gitList=$(cd "$dest"; git status -s)
    gitItem=$(echo $gitList | egrep "M \"$f\"")
    if [ ${#gitItem} -ne 0 ] 
        then 
            echo "$(date +%Y-%m-%d\ %H:%M:%S) \"$f\" pushed to github" 1>&2
            cd "$dest";git commit -m 'Regular update' "$f"
    fi
fi

