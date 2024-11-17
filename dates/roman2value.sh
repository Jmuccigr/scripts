#!/bin/bash

# A bash script demonstrating a function to get the value of a Roman numeral.
# The function does minimal error-checking, only making sure that the passed
# string has only the permitted letters (MDCLXVI) and spaces. The only rule is
# that smaller values placed before a larger one will be subtracted from it.
# A run of smaller values are treated together, and the numeral is processed
# left to right, so IX = 9 and XI = 11, as expected. Even non-standard values
# are handled, so IIII = 4, LLVV = 110, and IIX = 8. This allows for greater
# flexibility for the many non-standard values found in the wild, but also
# means that this script cannot be used to validate strings. In theory any
# string composed of valid characters will return a value.
#
# The script sets a global value, $romanValue, to the value of the numeral.
# You won't want to use that elsewhere in the script to avoid overwriting.
# It returns 0 if all goes well, and 1 if it doesn't, so checking $? will
# tell you what happened.
#
# There are two subfuntions embedded in the main one (convert) to maximize use
# of local variables. getValue sets a local variable to the value of the
# character. It does no error checking. The process function is where all
# the action happens. It works recursively to process the numeral from L to R.
#
# A test-suite with values. It has the regular characters, regular addition,
# subtraction, a big number, then irregular addition and subtraction:
# i v x  l    c   d ii xx xvi mcmlxvi iv vv xviiii iix
# 1 5 10 50 100 500  2 20  16    1966  4 10     19   8

################## Functions ####################
  
convert () {

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
  
  local arg=`echo "$1" | tr '[:lower:]' '[:upper:]' | tr -d ' '`
  local test=`echo "$arg" | sed 's/[MDCLXVI]//g'`
  if [[ $test != "" ]]; then
    return 1
  fi
  local total=0
  local run
  process "$arg"
  romanValue=$total
}

################ End functions ##################

convert "$1"
[[ $? == 0 ]] && echo $romanValue || echo "Not a Roman numeral"

