#!/bin/bash

# Send email when Zotero library export file has 0 size

me=$(whoami)

	if [ ! -s "/Users/$me/Documents/github/local/miscellaneous/My Library.json" ]
	then
		echo 'Darn it!' | mail -s 'Zotero export failed' john
    fi
