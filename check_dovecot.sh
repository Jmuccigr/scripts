result=`ps -ax | grep /usr/local/sbin/dovecot | grep -v grep`
if [[ $result == '' ]]
then
    /usr/local/bin/terminal-notifier -message "The mail server is not running." -title "Dovecot"
else
    echo "$(date +%Y-%m-%d\ %H:%M:%S) Dovecot is running." 1>&2
fi
