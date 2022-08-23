#!/bin/sh

# Get path of first selected file in Finder
osascript <<EOF
  tell application "Finder"
    set s to the selection
    set s1 to (item 1 of s as string)
    POSIX path of s1
  end tell
EOF

