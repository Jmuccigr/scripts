#!/bin/sh
# Used to sync scripts for CHDK of Canon camera.
# Assumes SD card is named UMBRIA-something & that only one is mounted.
# Pushes from computer to card, after erasing the scripts in the card's SCRIPTS folder

# Default to leaving newer files on disktool
# Change with flags as below
flags=' -vau'


# Read flags
while test $# -gt 0; do
  case "$1" in
    -h|--help)
      echo "Push CHDK Scripts to card [options]"
      echo ''
      echo 'options:'
      echo '-h, --help          show brief help'
      echo '-e, --erase         erase the scripts on the card before writing'
      echo '                    This will remove any extra scripts from the card.'
      echo '-o, --overwrite     overwrite the scripts on the card (leaving extras)'
      echo ''
      echo 'This script copies lua and basic scripts from the computer'
      echo 'to a mounted SD card called "UMBRIA"-something.'
      echo ''
      echo 'Default behavior is to replace only older versions on the card.'
      echo 'Change that with the options as above.'
      echo ''
      exit 0
      ;;
    -e|--erase)
      # e for erase
      rm -R /Volumes/UMBRIA*/CHDK/SCRIPTS/*.lua 1>/dev/null
      rm -R /Volumes/UMBRIA*/CHDK/SCRIPTS/*.bas 1>/dev/null
      shift
      ;;
    -o|--overwrite)
      # o for overwrite
      flags=' -va '
      shift
      ;;
    *)
      break
      ;;
  esac
done



rsync -vau ~/Documents/CHDK/CHDK\ scripts/ /Volumes/UMBRIA*/CHDK/SCRIPTS/ 1>/dev/null
