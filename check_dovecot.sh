result=`ps -ax | grep /usr/local/sbin/dovecot | grep -v grep`
[[ $result != '' ]] || terminal-notifier -message "The mail server is not running." -title "Dovecot"
