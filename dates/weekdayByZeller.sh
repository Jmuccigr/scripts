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

# Pass the date as 'YYYY MM DD'. You can use a non-numerical space between the
# numbers, like '.' or '/' or '-'. (Actually it can be anything as long as it
# doesn't contain a number.)
function parsedate () {
    if [ $# == 3 ]
    then
        yr=$1
        mo=$2
        d=$3
    elif [ $# == 1 ]
    then
        num='([0-9]+)'
        spacer='[^0-9]+'
        if [[ $1 =~ $num$spacer$num$spacer$num ]] ; then
          yr=${BASH_REMATCH[1]}
          mo=${BASH_REMATCH[2]}
          d=${BASH_REMATCH[3]}
        fi
    else # There's some other number of arguments
        badDate=true
    fi
    # Quick test of the values
    # Could do more here, like checking month and day numbers.
    if [[ $(( yr * mo * d )) == 0 ]]
    then
        badDate=true
    fi
    if [ $badDate ]
    then
        echo "That wasn't a date."
        exit 1
    fi
}

# Use Zeller's Congruence to calculate the day of the week from the date.
function zeller () {
  local weekdays=("Saturday" "Sunday" "Monday" "Tuesday" "Wednesday" "Thursday" "Friday")
  local q m y J K

  y=$1
  m=$2
  q=$3

  # Adjust for Jan and Feb
  if [[ $m -lt 3 ]]; then
    m=$(( m + 12 ))
    y=$(( y - 1 ))
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
  weekday=${weekdays[$dayoftheweek]}
}

################ End functions ##################

parsedate $@
zeller $yr $mo $d

[[ $? == 0 ]] && echo $weekday || echo "Something went wrong"


