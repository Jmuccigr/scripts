result=`ps -ax | grep /opt/homebrew/opt/dovecot/sbin/dovecot | grep -v grep`
if [[ $result == '' ]]
then
    /opt/homebrew/bin/terminal-notifier -message "The mail server is not running." -title "Dovecot"
else
    echo "$(date +%Y-%m-%d\ %H:%M:%S) Dovecot is running." 1>&2
fi
