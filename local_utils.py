from datetime import date, timedelta, timezone, datetime
import sys
import subprocess
import time

def send_mail(recipient, subject, message):
    sendmail_command = f"echo '{message}' | mail -s '{subject}' {recipient}"
    subprocess.run(sendmail_command, shell=True)

def log_this(msg, exit):
    timestamp = (f'{datetime.now():%Y-%m-%d %H:%M:%S%z}')
    print(timestamp, msg, file=sys.stderr)
    if exit:
        sys.exit()

def get_yesterday(days_before):
    yesterday = date.today() - timedelta(days=days_before)
    return yesterday
