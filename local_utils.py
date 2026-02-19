from datetime import datetime
import sys
import subprocess

def send_mail(recipient, subject, message):
    sendmail_command = f"echo '{message}' | mail -s '{subject}' {recipient}"
    subprocess.run(sendmail_command, shell=True)

def log_this(msg, exit):
    TIMESTAMP = (f'{datetime.now():%Y-%m-%d %H:%M:%S%z}')
    print(TIMESTAMP + " " + msg, file=sys.stderr)
    if exit:
        sys.exit()
