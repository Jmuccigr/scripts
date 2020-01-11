# Functions first

# Update my pip installation
update_pip () {
pipList=$(pip3 list --outdated | tail -n +3 | awk '{printf $1" "}')
# --format=columns
if [[ $pipList == '' ]]
then
    pip3Update="echo -e \npip3 up to date"
else
    echo -e "\nupdating pip3..."
    pip3Update="pip3 install -U $pipList"
fi
$pip3Update
$pipUpdate
}

# brew cask update
brewcask () {
  echo -e "\nUpdating brew cask"
  caskUpdates=$(brew cask outdated)
  if [[ $caskUpdates == '' ]]
    then
      echo "No cask updates"
    else
      brew cask reinstall $caskUpdates
      brew cask cleanup
  fi
}

# for mapping ease, get geojson output from existing services
vici () {
  curl -s -stdout "http://vici.org/object.php?id=$1" | jq '.'
}
dare () {
  curl -s -stdout "http://dare.ht.lu.se/api/geojson.php?id=$1" | jq '.'
}
pleiades () {
   open "http://pleiades.stoa.org/places/$1"
}

# Handy variables
me=$(whoami)

PS1="\A \w/ > "
PS2=" >"

# Jupyter
alias jn="cd /Users/$me/Documents/jupyter/; jupyter notebook"

# Jekyll: start (detached, if requestd) and kill
alias sj="cd /Users/$me/Documents/github/local/jmuccigr.github.io/; bundle exec jekyll serve $1"
alias kj="pkill -f jekyll"
alias jdir="cd /Users/$me/Documents/github/local/jmuccigr.github.io/"

#Holiday icons for prompts
[ "$(date +%d%m)" = "0101" ] && export PS1=$'\xf0\x9f\x8e\x89  \A \w/ >'
[ "$(date +%d%m)" = "1402" ] && export PS1=$'\xf0\x9f\x92\x98  \A \w/ >'
#[ "$(date +%d%m)" = "0407" ] && export PS1=$'\xf0\x9f\x87\xba\xf0\x9f\x87\b8  \A \w/ >'
[ "$(date +%m)"   = "10" ]   && export PS1=$'\xf0\x9f\x8e\x83  \A \w/ >'
[ "$(date +%d%m)" = "2710" ] && export PS1=$'\xf0\x9f\x8e\x81  \A \w/ >'
[ "$(date +%m)"   = "12" ]   && export PS1=$'\xf0\x9f\x8e\x85  \A \w/ >'

#For BBEdit, which otherwise has the wrong ones
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

#For GRASS GIS
export GRASS_PYTHON=/usr/bin/python2.6
export GRASS_PYTHONWX=/usr/bin/pythonw2.6

#export DYLD_LIBRARY_PATH=/Library/Frameworks/Mono.framework/Versions/Current/lib
#export DYLD_FALLBACK_LIBRARY_PATH=/Library/Frameworks/Mono.framework/Versions/Current/lib
#export LD_LIBRARY_PATH=/Library/Frameworks/Mono.framework/Versions/Current/lib
#export DYLD_FALLBACK_LIBRARY_PATH=$DYLD_FALLBACK_LIBRARY_PATH:/usr/lib

#export DYLD_LIBRARY_PATH="/usr/lib"

#export DYLD_LIBRARY_PATH=/Library/Frameworks/Mono.framework/Versions/Current/lib:/usr/lib
#export DYLD_FALLBACK_LIBRARY_PATH=/Library/Frameworks/Mono.framework/Versions/Current/lib:/usr/lib
#export DYLD_FALLBACK_LIBRARY_PATH=$DYLD_FALLBACK_LIBRARY_PATH:/usr/lib
#export LD_LIBRARY_PATH=/Library/Frameworks/Mono.framework/Versions/Current/lib:/usr/lib

#For VSFM
#export PATH=/Users/john_muccigrosso/Downloads/VisualSFM_OS_X_Mavericks_Installer-master/vsfm/bin:$PATH

#For rbenv
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"
#export RBENV_VERSION=jruby-1.7.3

#Adjusted this not to use gtk except from brew
export PKG_CONFIG_PATH=/usr/local/Cellar/pkg-config/0.28/bin/pkg-config:/usr/local/Cellar/

export BUNDLE_DIR=/Users/john_muccigrosso/.rbenv/versions/2.5.0/lib/ruby/gems/2.5.0/bundler/gems/

alias ..='cd ..'
alias cutf='iconv -f `uchardet $1` -t UTF-8 | pbcopy; pbpaste > $1'
alias h='history | tail -n 50'
alias ll='ls -aclG'
alias ff='sudo find'
alias ip='ipconfig getifaddr en0; ipconfig getifaddr en1'
alias grep='grep -i --color'
alias grepr='grep -i --color -d recurse'
alias sql='mysql --host=localhost -uroot -proot'
alias exif='exif --no-fixup' # prevents exif from modifying exif data
alias ql='qlmanage -p 2>/dev/null'
alias fle="perl -pi -e 's/\r\n?/\n/g' "
alias loginr="clear; ssh romerese@romeresearchgroup.org"
alias wkhtmltopdf="wkhtmltopdf --page-size Letter "
alias idsize='identify -format "%w x %h\n"'
alias thumb='convert -units pixelsperinch -density 75 -gravity center -resize 200x200 -background white -extent 200x200'
alias ccit='mogrify -threshold 80% -alpha off -monochrome -compress Group4 -quality 100 '
# Set up pandoc so that slideshows pause on each list item and the revealjs dir is set right
alias mypandoc="pandoc -i -V center=false -V transition=fade -V transitionSpeed=slow -V width=\'100%\' -V height=\'100%\' -V margin=0 -V revealjs-url=/Users/$me/Documents/github/local/reveal.js/"
alias pdoc='mypandoc -s --email-obfuscation=javascript --self-contained --columns 800 --atx-headers --pdf-engine=xelatex --bibliography="/Users/$me/Documents/github/local/miscellaneous/My Library.json"'
alias pandocreveal='pdoc -t revealjs'

# Easy updating of homebrew
alias bu='echo "Updating homebrew";brew update; brew upgrade; brew cleanup; brewcask'
# Easy updating of pip-installed stuff
alias pipUp=update_pip
# Easy updating of homebrew, pip, gem, and npm
alias upall='echo Checking brew; bu; echo ""; echo npm; npm -g update; echo ""; update_pip; echo ""; gem update'

# Skim commands
alias skimnotes=/Applications/Skim.app/Contents/SharedSupport/skimnotes
alias skimpdf=/Applications/Skim.app/Contents/SharedSupport/skimpdf

export TESSDATA_PREFIX=/usr/local/Cellar/tesseract/3.05.01/share/

#For other binaries
export PATH=$PATH:/Applications/MAMP/Library/bin
export PATH=$PATH:/Applications/MAMP/bin/php

# For bundler
#export PATH="~/bundler:~/bundler/bin:$PATH"
#export BUNDLER_BIN_PATH="/Users/john_muccigrosso/bundler/bin"

test -e "${HOME}/.iterm2_shell_integration.bash" && source "${HOME}/.iterm2_shell_integration.bash"
