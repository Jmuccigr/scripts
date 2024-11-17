#!/bin/bash

# A bash script to calculate the day of the week from Zeller's Congruence.
# The script writes the weekday to a global variable called "weekday".
# This takes into account the switch to the Gregorian calendar in Oct of 1582.
# That was a complicated switch, so for dates in Oct 4, 1582, be careful.
# Additionally the Julian calendar was a bit of a mess until AD 8 or so.
# Otherwise, you should be fine. :-)
#
# Variables are named as in the wikipedia article on the subject. These all need
# to be passed to the function as numbers. If you want to use month names, you
# need to convert them:
#
# q = day of the month (1-31)
# m = month where March = 3 & January & February are 13 & 14 (3-14) of 
#     the preceding year
# y = year (for reliability, from 8 on)

################## Functions ####################
  
function zeller () {
  local weekdays=("Saturday" "Sunday" "Monday" "Tuesday" "Wednesday" "Thursday" "Friday")
  local q m mo y J K
  # Use Zeller's Congruence to calculate the day of the week
  q=$1
  mo=$2
  yr=$3
  # Adjust for Jan and Feb
  if [[ $mo -lt 3 ]]; then
    m=$(( mo + 12 ))
    y=$(( yr - 1 ))
  else
    m=$mo
    y=$yr
  fi
  J=$(( y / 100 ))
  K=$(( y % 100 ))
  # Fix the date for the skipped Gregorian days by adding 10 to days in the gap
  [[ $y -eq 1582 && $m -eq 10 && $q -gt 4 && $q -lt 15 ]] && q=$(( q + 10 ))
  if [ $y -lt 1582 ] || ( [ $y -eq 1582 ] && [ $mo -eq 10 ] && [ $q -lt 15 ] ); then
    # Julian calendar
    dayoftheweek=$(( (q + ( ((13 * ( m + 1 ))) / 5) + K + ( K / 4 ) + 5 - J ) % 7 ))
  else
    # Gregorian calendar
    dayoftheweek=$(( (q + ( ((13 * ( m + 1 ))) / 5) + K + ( K / 4 ) + ( J / 4 ) - 2*J ) % 7 ))
  fi
  [[ $dayoftheweek -lt 0 ]] && dayoftheweek=$(( 7 + dayoftheweek ))
  echo -n "$yr "
  weekday=${weekdays[$dayoftheweek]}
}

################ End functions ##################

zeller $1 $2 $3
[[ $? == 0 ]] && echo $weekday || echo "Something went wrong"


