# Script to move a Zotero document file back and forth to iCloud so that
# it can be worked on using other devices

set archive to POSIX path of (path to library folder from user domain) & "Mobile Documents/com~apple~CloudDocs/Zotero/"
set archive_folder to POSIX file archive as alias
# Use enough of the path to convince you the file is in the Zotero storage area
set zotero_path_fragment to "Zotero data"
set notification to ""

tell application "Finder"
	set s to the selection
	set zotfile to (item 1 of s)
	set zotname to name of zotfile as string
	set zotfilefolder to (container of zotfile)
	
	if zotfilefolder as string = archive_folder as string then
		set destination to comment of zotfile
		if destination is "" then
			display dialog "This file has no stored original information. You have to work with the Zotero file, not this copy in iCloud." with title "iCloud" buttons {"OK"} default button 1 with icon stop giving up after 30
			error number -128
		else
			try
				move zotfile to (container of alias destination) with replacing
				set comment of (file zotname of (container of alias destination)) to ""
				set notification to "File successfully copied to iCloud."
			on error errMsg number errNum
				display alert "Oops" message "Something went wrong retrieving file: Error" & errNum & return & errMsg giving up after 30
				error number -128
			end try
		end if
	else
		if zotfilefolder as string does not contain zotero_path_fragment then
			display dialog "You have to work with a file in Zotero storage." with title "Not in Storage" buttons {"OK"} default button 1 with icon stop giving up after 30
			error number -128
		else
			try
				duplicate zotfile to archive_folder
				set comment of (file zotname of archive_folder) to (zotfile as string)
				set notification to "File successfully copied to iCloud."
			on error errMsg
				if errMsg is "An item with the same name already exists in this location." then
					set reply to button returned of (display dialog "There is already a file in the Zotero iCloud folder with this name. Retrieve, overwrite it or cancel?" buttons {"Overwrite", "Retrieve", "Cancel"} default button 3 with icon caution with title "File already exists")
				end if
				if reply is "Retrieve" then
					try
						move file zotname of archive_folder to zotfilefolder with replacing
						set comment of file zotname of zotfilefolder to ""
						set notification to "File successfully retrieved from iCloud."
					on error errMsg number errNum
						if errMsg is "An item with the same name already exists in this location." then
							display alert "Ooops" message "Something went wrong: Error" & errNum & return & errMsg giving up after 30
							error number -128
						end if
					end try
				else
					duplicate zotfile to archive_folder with replacing
					set comment of (file zotname of archive_folder) to (zotfile as string)
					set notification to "File successfully re-copied to iCloud."
				end if
			end try
		end if
	end if
	
	if notification is not "" then
		display notification notification with title "Zotero - iCloud" sound name "beep"
	end if
	
end tell
