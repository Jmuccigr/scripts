#!/Users/john_muccigrosso/.venv/bin/python3

# A script to check an RSS feed and share the latest new entry on Bluesky.
# Guts of it are from <https://sperea.es/blog/bot-bluesky-rss>, but now
# with sigificant upgrades, including the use of the atproto library.
# It will grab an image from the rss, defaulting to the feed icon.
# It logs both success and failure.
# I also pushed some constants into files for privacy.

from atproto import Client, client_utils
from datetime import datetime, timezone
from PIL import Image
import feedparser
import io
from io import BytesIO
import json
import os.path
import re
import sys
import time
import urllib3 
#from urllib.request import urlopen 

# Constants
CHECK_FILE = "blogpost_date.txt"
BLUESKY_PW_FILE = "bluesky_app_password.txt"
BLUESKY_HANDLE_FILE = "bluesky_handle.txt"
MAX_POSTS = 3
MAX_IMAGE_SIZE = 1000000
FEED_URL = "https://jmuccigr.github.io/feed.xml"
BLUESKY_API_ENDPOINT = "https://bsky.social/xrpc/com.atproto.repo.createRecord"
API_KEY_URL = "https://bsky.social/xrpc/com.atproto.server.createSession"
POST_DELAY = 5 #in seconds

def compare_post_dates(post_date):
    global pubdate

    # If not already done, check the file for the lastest published date.
    # Report error & set an absurdly early date if the file doesn't exist
    if pubdate == "":
        if not os.path.isfile(check_file):
            pubdate="1900-01-01T00:00:01+00:00"
            with open(check_file, 'x') as file:
                file.write(pubdate)
                print(timestamp + " Blog post check file does not exist", file=sys.stderr)
        else:
            # Open the file and read the date of the last published blog post.
            f = open(check_file, "r")
            pubdate = f.readlines()[0].replace("\n", "")

    latest_post_date = datetime.strptime(post_date, "%Y-%m-%dT%H:%M:%S%z")
    last_published_date = datetime.strptime(pubdate, "%Y-%m-%dT%H:%M:%S%z")
    if latest_post_date > last_published_date:
        return latest_post_date  # latest post is newer
    else:
        return False # last published is newer

def get_rss_content():

    ct=0
    # Parse the RSS feed
    rssfeed = feedparser.parse(FEED_URL)
    if hasattr(rssfeed.feed, 'icon'):
        icon = rssfeed.feed.icon
    else:
        icon = ""
    validEntries=[]
    # Iterate through the entries in the feed until we have enough or they're exhausted
    max_posts=min(MAX_POSTS, len(rssfeed.entries))
    for entry in rssfeed.entries:
        if ct < max_posts:
            post_title = entry.title
            post_link = entry.link
            if hasattr(entry, 'media_thumbnail'):
                post_image = entry.media_thumbnail[0]['url']
                post_image_desc = "Image from the post"
            else:
                post_image = icon
                post_image_desc = "blog icon"

            # Use only one of the next two lines.
            post_date = entry.updated
#             post_date = entry.published

            response=compare_post_dates(post_date)
            if response:
                ct += 1
                temp = dict()
                temp["title"] = post_title
                temp["link"] = post_link
                temp["image"] = post_image
                temp["image_desc"] = post_image_desc
                validEntries.append(temp)

    #return latest_post_title, latest_post_link, latest_post_date
    if ct > 0:
        return validEntries
    else:
        return False

def prepare_post_for_bluesky(title, link):
    # Convert the RSS item into a format suitable for Bluesky.

    short_title=title[0:240]

    tb = client_utils.TextBuilder()
    tb.text("I just blogged...\n\n" + short_title + "\n\nRead more ")
    tb.link("here", link)
    tb.text(".")

    return tb

def prepare_image(image_url):
    http = urllib3.PoolManager()
    try:
        response = http.request("GET", image_url)
        status = response.status
        if (response.status != 200):
            print(timestamp + " Unable to download image file. Error " + response.status.__str__() + ": " + image_url, file=sys.stderr)
            return ""
        img_data = response.data
        # Using a quick and dirty rule of thumb: images less than dim in size will be
        # below the size limit for Bluesky. If an image is too big, just shrink it
        # right away and don't sweat it. Alternative would be to iteratively shrink it
        # until it's small enough.
        if (sys.getsizeof(img_data)) > MAX_IMAGE_SIZE:
            img = Image.open(BytesIO(img_data))
            if img.format in ("JPEG", "GIF"):
                dim=800
            else:
                dim=400
            img.thumbnail((dim,dim))
            img_byte_arr = io.BytesIO()
            img.save(img_byte_arr, format=img.format)
            img_data = img_byte_arr.getvalue()
    except:
        # Log error & return something small
        print(timestamp + " Unable to get image file: " + image_url, file=sys.stderr)
        img_data = ""
        
    return(img_data)

def bluesky_rss_bot(app_password, client):
    # Fetch content from the RSS feed
    validEntries = get_rss_content()
    # Only do something if there are valid entries
    if validEntries:
        # Authenticate and obtain necessary credentials
        ct=0
        # Prepare the fetched content for Bluesky
        for entry in validEntries:
            # Wait a little if posting more than one entry
            if ct > 0:
                time.sleep(POST_DELAY)
            ct += 1
            post_structure = prepare_post_for_bluesky(entry["title"], entry["link"])
            if entry["image"] == "":
                bluesky_reply = client.send_post(post_structure)
            else:
                image_url = entry["image"]
                img_data = prepare_image(image_url)
                if sys.getsizeof(img_data) < 100:
                    print(timestamp + " Bluesky post image couldn't be retrieved", file=sys.stderr)
                    bluesky_reply = client.send_post(post_structure)
                else:
                    bluesky_reply = client.send_image(text=post_structure, image=img_data, image_alt=entry["image_desc"])
            try:
                reply = reply + bluesky_reply
            except:
                reply = bluesky_reply

        print(timestamp + " Published latest blog post to Bluesky", file=sys.stderr)
        return reply
    else:
        print(timestamp + " Latest blog post already published", file=sys.stderr)
        return "No need to publish."

def main():
    global check_file
    global handle
    global timestamp
    global pubdate

    pubdate=""

    # Get timestamps for log entries and comparison
    timestamp =(f'{datetime.now():%Y-%m-%d %H:%M:%S%z}')
    check_date=datetime.now(timezone.utc).isoformat(sep="T", timespec="seconds")
    # Get needed info from files. Adjust userpath as needed.
    userpath=(re.sub("^(.+/Documents/).*", r"\1", os.path.dirname(os.path.realpath(__file__))))
    check_file = userpath + CHECK_FILE
    pw_file = userpath + BLUESKY_PW_FILE
    handle_file=userpath + BLUESKY_HANDLE_FILE
    if not os.path.isfile(pw_file):
        print(timestamp + " Bluesky password file does not exist", file=sys.stderr)
    elif not os.path.isfile(handle_file):
        print(timestamp + " Bluesky handle file does not exist", file=sys.stderr)
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
            print(timestamp + " Problem logging into Bluesky", file=sys.stderr)
            # Trapping this, but not doing anything with it now
            e = sys.exc_info()[1]
        else:
            response = bluesky_rss_bot(app_pw, client)
            # Finish by writing the date to file for next run
            with open(check_file, 'w') as f:
                f.write(check_date)
                f.close()
            print(response)

if __name__ == "__main__":
    main()
