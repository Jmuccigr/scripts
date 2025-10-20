# Zotero-related scripts

bash scripts to keep Zotero and Obsidian in sync. These complement the Zotero plug-in for Obsidian:

- zot2obsidian.sh: sync up note files
- zotero_check_tags.sh: compare tags (can't just update metadata from Zotero)

javascripts to manipulate the zotero database while it's running:

- load_URLs_from_file.js: create entries for URLs found in a text file
- replace_field_value.js: replace the entire contents of a field when it matches a search string
- replace_field_value_in_saved_search.js: same as previous, but in a specific saved search. Use the `zotero web api.md` script to get the key to the search.
- replace_partial_field_value.js: replace the first instance of the occurrence of a search string in a field
- replace_partial_field_value_in_saved_search.js: same as previous, but in a specific saved search. Use the `zotero web api.md` script to get the key to the search.
- zotero_web_api.md: URL for grabbing info via the web API

Applescript to replace Zotfile functionality to some extent:

- Mange Zotero file.applescript: shuffle PDF back and forth from Zotero storage to iCloud for easy editing on the iPad. *Copy* from Zotero, *move* from iCloud.
