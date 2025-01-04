#!/Users/john_muccigrosso/.venv/bin/python3

from atproto import Client, client_utils
import io
import re
import sys
from datetime import date, timedelta, datetime, timezone
import time
import urllib3
import tempfile
import os
import subprocess

# Constants
CHECK_FILE = "uk_date.txt"
BLUESKY_PW_FILE = "bluesky_app_password_energy.txt"
BLUESKY_HANDLE_FILE = "bluesky_handle_energy.txt"
TMPDIR = tempfile.gettempdir() + '/'
MAX_POSTS = 3
MAX_IMAGE_SIZE = 1000000
BLUESKY_API_ENDPOINT = "https://bsky.social/xrpc/com.atproto.repo.createRecord"
API_KEY_URL = "https://bsky.social/xrpc/com.atproto.server.createSession"
ERRMSG=""
TIMESTAMP =(f'{datetime.now():%Y-%m-%d %H:%M:%S%z}')
yesterday = date.today() - timedelta(days=1)
YES=yesterday.strftime("%Y-%m-%d")
DATA_URL='https://api.neso.energy/dataset/88313ae5-94e4-4ddc-a790-593554d8c6b9/resource/f93d1835-75bc-43e5-84ad-12472b180a98/download/df_fuel_ckan.csv'

def compare_post_dates(yesterday, check_file):
    # Check the file for the lastest published date.
    # Report error & set an absurdly early date if the file doesn't exist
    if not os.path.isfile(check_file):
        pubdate="1900-01-01"
        with open(check_file, 'x') as file:
            file.write(pubdate)
            print(TIMESTAMP + " Check file does not exist", file=sys.stderr)
    else:
        # Compare the recorded date with yesterday's date.
        f = open(check_file, "r")
        pubdate = f.readlines()[0].replace("\n", "")
    if pubdate != yesterday:
        return True  # latest post is older than yesterday
    else:
        return False # latest post was for yesterday

def get_data(userpath):
    https = urllib3.PoolManager()
    response = https.request("GET", DATA_URL, preload_content=False)
    response.auto_close = False

    # Make sure the URL is correct
    stat=response.status
    if (stat != 200):
        ERRMSG="Error retrieving file from NESO. Status: " + stat
        print(TIMESTAMP + ERRMSG, file=sys.stderr)
        sys.exit()

    # Output to a text file, filtering out unwanted dates
    outputFile=TMPDIR + YES + "_ukdata.csv"
    i=1
    with open(outputFile, 'w') as f:
        for line in io.TextIOWrapper(response):
            if (i==1):
                    f.write(line)
                    i=2
            if (re.search(YES, line)):
                    f.write(line)

    # Check for enough data in the download. Should be something like 9.5k.
    filesizecheck=os.path.getsize(outputFile)
    if(filesizecheck < 8000):
        ERRMSG="File received from NESO is too small. Size: " + filesizecheck
        print(TIMESTAMP + ERRMSG, file=sys.stderr)
        sys.exit()
    else:
        try:
            os.rename(TMPDIR + "uk.txt", TMPDIR + "uk.txt.old")
        except:
            pass
        try:
            os.rename(TMPDIR + "uk.png", TMPDIR + "uk.png.old")
        except:
            pass
        subprocess.call (re.sub("Documents/", "", userpath) + "R projects/UK_power.R")

def prepare_post_for_bluesky():
    # Convert the text file into a format suitable for Bluesky.
    tb = client_utils.TextBuilder()
    f = open(TMPDIR + "uk.txt", "r")
    skeettxt = f.read()
    tb.text(skeettxt)
    tb.text("\nSource: ")
    tb.link("NESO", "https://www.neso.energy/data-portal/historic-generation-mix")
    tb.text(".\n\n")
    tb.tag("#UK", "UK")
    tb.text(" ")
    tb.tag("#windenergy", "windenergy")
    tb.text(" ")
    tb.tag("#solarenergy", "solarenergy")
    return tb

def prepare_image_for_bluesky():
    try:
        f = open(TMPDIR + "uk.png", "rb")
        img_data = f.read()
    except:
        e = sys.exc_info()[1]
        img_data = ""
    return(img_data)

def prepare_alttext_for_bluesky():
    f = open(TMPDIR + "ukalt.txt", "r")
    alttxt = f.read()
    return(alttxt)

def bluesky_bot(app_password, client):
    altxt = ""
    post_structure = prepare_post_for_bluesky()
    img_data = prepare_image_for_bluesky()
    alttxt = prepare_alttext_for_bluesky()
    if img_data == "":
        print(TIMESTAMP + " Bluesky post image couldn't be retrieved", file=sys.stderr)
        sys.exit()
        bluesky_reply = client.send_post(post_structure)
    else:
        bluesky_reply = client.send_image(text=post_structure, image=img_data, image_alt="Pie chart showing UK power generation for yesterday, " + YES + ": " + alttxt)
    try:
        reply = reply + bluesky_reply
    except:
        reply = bluesky_reply

        print(TIMESTAMP + " Published latest UK power to Bluesky", file=sys.stderr)
        return reply
    else:
        print(TIMESTAMP + " Latest UK power already published", file=sys.stderr)
        return "No need to publish."

def main():

    # Get needed info from files. Adjust userpath as needed.
    userpath=(re.sub("^(.+/Documents/).*", r"\1", os.path.dirname(os.path.realpath(__file__))))
    
    # Make sure yesterday hasn't been done yet
    check_file = userpath + CHECK_FILE
    response=compare_post_dates(YES, check_file)
    if response:
        pw_file = userpath + BLUESKY_PW_FILE
        handle_file=userpath + BLUESKY_HANDLE_FILE
        if not os.path.isfile(pw_file):
            print(TIMESTAMP + " Bluesky password file does not exist", file=sys.stderr)
        elif not os.path.isfile(handle_file):
            print(TIMESTAMP + " Bluesky handle file does not exist", file=sys.stderr)
        else:
            # Get needed info from files
            f = open(pw_file, "r")
            app_pw = f.readlines()[0].replace("\n", "")
            f = open(handle_file, "r")
            handle = f.readlines()[0].replace("\n", "")
            # Do the actual work
            client = Client()
            try:
                client.login(handle, app_pw)
            except:
                print(TIMESTAMP + " Problem logging into Bluesky", file=sys.stderr)
                # Trapping this, but not doing anything with it now
                e = sys.exc_info()[1]
            else:
                get_data(userpath)
                response = bluesky_bot(app_pw, client)
                # Finish by writing yesterday's date to check file for next run
                with open(check_file, 'w') as f:
                    f.write(YES)
                    f.close()
                print(response)
    else:
        print(TIMESTAMP + " UK data already posted for " + YES, file=sys.stderr)

if __name__ == "__main__":
    main()
