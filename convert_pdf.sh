#!/bin/bash

# Use pdfimages to get correct dpi of converted pdf
# Syntax is the same as the convert command, but we get the dpi of 
# the pdf first and insert that into the convert command

fname=("$@")
counter=0
until [ $counter = $# ]; do
	# Find the first pdf file in the command
	i=${fname[$counter]}
	j=$(echo $i | tr '[:upper:]' '[:lower:]')
	if [ "${j##*.}" = 'pdf' ] && [ "${i%.*}" != '' ]
	then
		# Get its dpi
	    s=$(pdfimages -list "${fname[$counter]}" | grep '%' | head -n 1)
		a=( $s )
		INV=' '
		dpi=${a[12]}
	fi
	((counter++))
done

# Pass the rest of the command on to convert, inserting the dpi info
convert -density $dpi "$@"
