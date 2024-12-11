#!/bin/bash

# A script to convert a Roman-style date to a modern style.
# It accounts for the Julian/Gregorian differences.
# Not much error-checking, so a nonsensical date like "43 kal Mar" "works".
# Assumes input is in form "[days-before] named-day month [year]",
# where the days-before starts with a number and trailing text is ignored;
# named-day must start with k, n, or i (kalends, nones, & ides);
# some variations on month names are allowed, including different cases, so
# month is the first three letters of the month name in Latin or English
# (i.e., "May" and "Mai" are both good); jan/jen also both work;
# and year is in the modern system.
# It's just doing a name change, not trying to find astronomical equivalents.
# Given a year, it will provide the day of the week using Zeller's Congruence.

mList=("ian" "feb" "mar" "apr" "mai" "iun" "iul" "aug" "sep" "oct" "nov" "dec")
mListLong=("January" "February" "March" "April" "May" "June" "July" "August" "September" "October" "November" "December")
fullMonths=("mar" "mai" "iul" "oct")
mLength=(31 28 31 30 31 30 31 31 30 31 30 31)
warn=""
y=9999
leapyear=false
errMsg=""

args=$@
wordCt=$#
charCt=`echo $@ | wc -c`

if [[ wordCt -lt 2 || charCt < 6 ]]; then
  echo "The date string appears to be too short."
  exit 1
fi

################## Functions ####################
function convertRoman () {

  getValue () {
    local chars=("M" "D" "C" "L" "X" "V" "I")
    local values=(1000 500 100 50 10 5 1)
    place=`echo ${chars[@]/$1//} | cut -d/ -f1 | wc -w | tr -d ' '`
    value=${values[$place]}
  }

  process () {
    local value
    local num=$1
    charCt=`echo -n $num | wc -c`
    if [[ $charCt -eq 0 ]]; then
      return 0
    else
      if [[ $charCt -eq 1 ]]; then
        getValue $num
        total=$(( total + run + value ))
      else
        current=${num:0:1}
        next=${num:1:1}
        getValue $current; currentVal=$value
        getValue $next; nextVal=$value
        run=$(( run + currentVal ))
        if [[ $currentVal -ne $nextVal ]]; then
          [[ $currentVal -lt $nextVal ]] && total=$(( total - run )) || total=$(( total + run ))
          run=0
        fi
      fi
    fi
    newString=${num:1:charCt}
    if [[ $newString != "" ]]; then
      process $newString
    else
      return 0
    fi
  }
  
  local arg=`echo "$1" | tr '[:lower:]' '[:upper:]' | tr -d ' ' | tr -d '.'`
  local test=`echo "$arg" | sed 's/[MDCLXVI]//g'`
  if [[ $test != "" ]]; then
    return 1
  fi
  local total=0
  local run
  process "$arg"
  romanValue=$total
}

function getDayCount () {
  # Get number from start of datestring; p means pridie, po = postridie
  t=$1
  if [[ ${t:0:2} == "pr" ]]; then
    d=2
  else
    if [[ ${t:0:2} == "po" ]]; then
      d=0
    else
      if ! [ "$d" -eq "$d" ] 2>/dev/null; then
        #assume the number is a Roman numeral
        convertRoman "$t"
        if [[ "$?" == 0 ]]; then
          d=$romanValue
        else
          echo "Something went wrong with the conversion of "$1" from Roman numerals."
          exit 1
        fi
      fi
    fi
  fi
  d=$(( $d - 1 ))
}

function getNamedDay () {
  t=`echo "$1" | tr '[:upper:]' '[:lower:]' | tr -d ' ' | tr -d '.'`
  if [[ ! "kni" =~ ${t:0:1} ]]; then
    errMsg="The named day in the date string appears to be invalid."
    return 0
  fi
  val=1
  if [[ ${t:0:1} == "i" ]]; then
    val=13
  else
    if [[ ${t:0:1} == "n" ]]; then
      val=5
    fi
  fi
  namedDay=$val
  #  Correct for the full months
  fm=`echo ${fullMonths[@]/$cleanmon//} | cut -d/ -f1 | wc -w | tr -d ' '`
  [[ $namedDay -gt 1 && $fm -lt 4 ]] && namedDay=$(( namedDay + 2 ))
}

function getMonthNumber () {
  test=`echo $1 | wc -c`
  if [[ $test -lt 4 ]]; then
    errMsg="Month name is too short."
    return 1
  fi
  # Allow for non-Latin spellings with i for y and j for i
  cleanmon=`echo $1 | tr '[:upper:]' '[:lower:]' | tr 'y' 'i' | tr 'j' 'i'`
  cleanmon=`echo $cleanmon | perl -pe 's/^ien/ian/'`
  cleanmon=${cleanmon:0:3}
  mo=`echo ${mList[@]/$cleanmon//} | cut -d/ -f1 | wc -w | tr -d ' '`
  if [[ $mo -eq 12 ]]; then
    errMsg="No match for the month name."
    return 1
  fi
  mo=$(( mo + 1 ))
}

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
  # Fix the date for the skipped Gregorian days
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

################ End Functions ##################

if [[ wordCt -eq 2 ]]; then
  # We have just named day and month
  d=0
  namedDay=$1
  mon=$2
else
  if [ $3 -eq $3 ] 2>/dev/null; then 
    # 3rd arg is year, so we have named day - month - year
    d=0
    namedDay=$1
    mon=$2
    y=$(( $3 ))
  else
    # 3rd arg is NOT year, so day - named day - month
    d=`echo $1 | sed -r 's/(^[0-9]+).*/\1/'`
    namedDay=$2
    mon=$3
    getDayCount $d
    # Check 4th item for year
    if [[ $# -gt 3 ]]; then 
      if [ $4 -eq $4 ] 2>/dev/null; then 
        y=$4
      fi
    fi
  fi
fi

# Identify leap years
[[ $(( y % 4 )) -eq 0 ]] && leapyear=true
# Make the correction for post-Gregorian years
if [[ $y -gt 1582 ]]; then
  if [[ $(( y % 100 )) -eq 0 ]]; then
    [[ $(( y % 400 )) -eq 0 ]] && leapyear=true || leapyear=false
  fi
fi

# Convert month to a number
getMonthNumber $mon
if [[ $errMsg != "" ]]; then
  echo $errMsg
  exit 1
fi

# Convert named day to a day of the month (number)
getNamedDay $namedDay
if [[ $errMsg != "" ]]; then
  echo $errMsg
  exit 1
fi

# Correct year, month, and day for kalends
if [[ $namedDay -eq 1 && $d -gt 0 ]]; then
  # Uncomment the next line if the year belongs to the month and not the day,
  # so all Jan dates are with the year that starts after Jan 1
  # [[ $mo -eq 1 ]] && y=$(( y - 1 ))
  mo=$(( mo - 1 ))
  [[ $mo -eq 0 ]] && mo=12
  namedDay=${mLength[$mo-1]}
  namedDay=$(( namedDay + 1 ))
  [[ $leapyear == true && $mo -eq 2 ]] && namedDay=$(( namedDay + 1 ))
fi

finalDay=$(( namedDay - d ))

# Display date in nice format. Use 9999 (=y) because it's not a leap year.
# Warn if there's no year given and the date is in late February
[[ $y == 9999 && $mo -eq 2 && $namedDay -gt 13 ]] && echo -n "In leap years, add 1 to this date: "

# Get the weekday if the year was specified
[[ y -lt 9999 ]] && zeller $finalDay $mo $y

# This outputs the variables with a zeller lookup
echo -n $weekday ${mListLong[$mo-1]} $finalDay
[[ $y == 9999 ]] || echo -n ", $y"
echo ""

echo ${mListLong[$mo-1]} $finalDay"," $y | pbcopy

# The next part would work if date handled years before 1900
# if [[ y -lt 9999 ]]; then
#   outputFormat="%h %e, %Y"
# else
#   outputFormat="%h %e"
# fi
# echo `date -j -f "%Y %m %d" "$y $mo $finalDay" +"$outputFormat"`
# This uses applescript to get the weekday:
# dstring="$mo/$finalDay/$y"
# echo `osascript -e "set d to date string of date \\"$dstring\\""`
