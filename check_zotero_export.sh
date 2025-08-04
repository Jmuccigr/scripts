#!/bin/bash

# Send email when Zotero library export file has 0 size

me=$USER
dest="/Users/$me/Documents/github/local/miscellaneous"
f="My Library.json"
if [ ! -s "$dest/$f" ]
then
    #echo 'Darn it' | mail -s 'Zotero export failed' "$me"
    /opt/homebrew/bin/terminal-notifier -message "Zotero export failed." -title "Zotero"
    echo "$(date +%Y-%m-%d\ %H:%M:%S) Zotero export has failed." 1>&2
    if [ -e "$dest/$f" ]
    then
        rm "$dest/$f"
    fi
else
    # Commit it to github when it's changed
    gitList=$(cd "$dest"; git status -s)
    gitItem=$(echo $gitList | egrep "M \"$f\"")
    if [ ${#gitItem} -ne 0 ]
        then
            echo "$(date +%Y-%m-%d\ %H:%M:%S) \"$f\" pushed to github" 1>&2
            cd "$dest";git commit -m 'Automated update' "$f"; git push
    fi
fi
