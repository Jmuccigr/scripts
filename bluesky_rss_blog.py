#!/Users/john_muccigrosso/.atproto/bin/python3

# A script to check an RSS feed and share the latest new entry on Bluesky.
# Guts of it are from <https://sperea.es/blog/bot-bluesky-rss>, but now
# with sigificant upgrades, including the use of the atproto library.
# It will grab an image from the rss, defaulting to the feed icon.
# It logs both success and failure.
# I also pushed some constants into files for privacy.

from atproto import Client, client_utils, models, Session, SessionEvent
import atsession
from bs4 import BeautifulSoup
from datetime import datetime, timezone
from PIL import Image
import feedparser
import io
from io import BytesIO
import json
import os.path
import re
import sys
import tempfile
import time
import urllib3 
from local_utils import *

# Constants
userpath=re.sub(r"^(.+\/Documents\/).*", r"\1", os.path.dirname(os.path.realpath(__file__)))
TMPDIR = tempfile.gettempdir() + "/"
BLUESKY_PW_FILE = userpath + "bluesky_app_password.txt"
BLUESKY_HANDLE_FILE = userpath + "bluesky_handle.txt"
CHECK_FILE = userpath + "blogpost_date.txt"
MAX_POSTS = 3
MAX_IMAGE_SIZE = 1000000
EMBED_IMG = TMPDIR + "blogscreencap.jpg"
FEED_URL = "https://jmuccigr.github.io/feed.xml"
BLUESKY_API_ENDPOINT = "https://bsky.social/xrpc/com.atproto.repo.createRecord"
API_KEY_URL = "https://bsky.social/xrpc/com.atproto.server.createSession"
atsession.SESSION_FILE = TMPDIR + "bluesky_session.txt"
POST_DELAY = 5 #in seconds

# def get_session() -> Optional[str]:
#     try:
#         with open(SESSION_FILE, encoding='UTF-8') as f:
#             return f.read()
#     except FileNotFoundError:
#         return None
# 
# def save_session(session_string: str,) -> None:
#     with open(SESSION_FILE, 'w', encoding='UTF-8') as f:
#         f.write(session_string)
# 
# def on_session_change(event: SessionEvent, session: Session) -> None:
#     print('Session changed:', event, repr(session))
#     if event in (SessionEvent.CREATE, SessionEvent.REFRESH):
#         print('Saving changed session')
#         save_session(session.export())

def compare_post_dates(post_date):
    global pubdate

    # If not already done, check the file for the lastest published date.
    # Report error & set an absurdly early date if the file doesn't exist
    if pubdate == "":
        if not os.path.isfile(CHECK_FILE):
            pubdate="1900-01-01T00:00:01+00:00"
            with open(CHECK_FILE, 'x') as file:
                file.write(pubdate)
                log_this("Blog post check file does not exist", False)
        else:
            # Open the file and read the date of the last published blog post.
            f = open(CHECK_FILE, "r")
            pubdate = f.readlines()[0].replace("\n", "")
    try:
        last_published_date = datetime.strptime(pubdate, "%Y-%m-%dT%H:%M:%S%z")
    except Exception as e:
        log_this("Something wrong with last pub date in local file: " + e.__str__(), True)
    latest_post_date = datetime.strptime(post_date, "%Y-%m-%dT%H:%M:%S%z")
    if latest_post_date > last_published_date:
        return latest_post_date  # latest post is newer
    else:
        return False # last published is newer

def takeScreencap (url):
    title = ""
    result = os.system("cd " + TMPDIR + ";pageres --overwrite --format=jpg " + url + " --filename=blogscreencap 1024x768 --crop")
    if (result != 0):
        log_this("Blog embed screencap didn't work:" + result.__str__(), False)
    else:
        http = urllib3.PoolManager()
        r = http.request('GET', url, headers={'User-Agent': 'Mozilla/5.0'})
        soup = BeautifulSoup(r.data.decode('utf-8'), features="lxml")
        title_tag = soup.find("meta", property="og:title")
        if title_tag:
            title = title_tag["content"]
        else:
            title = soup.title.string
        description_tag = soup.find("meta", property="og:description")
        if description_tag:
            body = description_tag["content"]
        else:
            body = soup.article.get_text(' ', strip=True)[0:200]
    return(result, title, body)

def prepare_embedded_link(title, desc, url):
    # This shouldn't happen, but just in case
    if (url == ""):
        embed = ""
    else:
        with open(EMBED_IMG, 'rb') as f:
          img_data = f.read()

        thumb = client.upload_blob(img_data)
        embed = models.AppBskyEmbedExternal.Main(
            external=models.AppBskyEmbedExternal.External(
                title=title,
                description=desc,
                uri=url,
                thumb=thumb.blob,
            )
        )
    return(embed)

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
            # Use thumbnail if included, otherwise screenshot
            if hasattr(entry, 'media_thumbnail'):
                post_image = entry.media_thumbnail[0]['url']
                post_image_desc = "Image from the post"
            else:
                post_image = ""
                post_image_desc = ""
#                 post_image = icon
#                 post_image_desc = "blog icon"

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
            log_this("Unable to download image file. Error " + response.status.__str__() + ": " + image_url, False)
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
        log_this("Unable to get image file: " + image_url, False)
        img_data = ""
        
    return(img_data)

def bluesky_rss_bot(validEntries):
    global client
    
    # Authenticate and obtain necessary credentials
    ct = 0
    # Prepare the fetched content for Bluesky
    for entry in validEntries:
        # Wait a little if posting more than one entry
        if ct > 0:
            time.sleep(POST_DELAY)
        else:
            ct = 1
        post_structure = prepare_post_for_bluesky(entry["title"], entry["link"])
        if entry["image"] == "":
            result, title, body = takeScreencap(entry["link"])
            if (result == 0):
                embed = prepare_embedded_link(title, body, entry["link"])
                bluesky_reply = client.send_post(post_structure, embed=embed)
            else:
                log_this("Bluesky embed image couldn't be taken", False)
                bluesky_reply = client.send_post(post_structure)
        else:
            image_url = entry["image"]
            img_data = prepare_image(image_url)
            if sys.getsizeof(img_data) < 100:
                log_this("Bluesky post image couldn't be retrieved", False)
                bluesky_reply = client.send_post(post_structure)
            else:
                bluesky_reply = client.send_image(text=post_structure, image=img_data, image_alt=entry["image_desc"])
        try:
            reply = reply + bluesky_reply
        except:
            reply = bluesky_reply

    log_this("Published latest blog post to Bluesky", False)
    return reply

def init_client() -> Client:
    global client

    if (not os.path.isfile(BLUESKY_PW_FILE)):
        log_this("Bluesky password file does not exist", True)
    elif (not os.path.isfile(BLUESKY_HANDLE_FILE)):
        log_this("Bluesky handle file does not exist", True)
    else:
        # Get needed info from files
        f = open(BLUESKY_PW_FILE, "r")
        app_pw = f.readlines()[0].replace("\n", "")
        f = open(BLUESKY_HANDLE_FILE, "r")
        handle = f.readlines()[0].replace("\n", "")
        # Do the actual work
        client = Client()
        try:
            client.on_session_change(atsession.on_session_change)

            session_string = atsession.get_session()
            if session_string:
                print('Reusing session')
                client.login(session_string=session_string)
            else:
                print('Creating new session')
                client.login(handle, app_pw)
        except:
            log_this("Problem logging into Bluesky", False)
            # Trapping this, but not doing anything with it now
            e = sys.exc_info()[1]
            print(e)
            return False
        else:
            return True

def main():
#     global client
    global pubdate

    pubdate = ""

    check_date = datetime.now(timezone.utc).isoformat(sep="T", timespec="seconds")
    # Fetch content from the RSS feed
    validEntries = get_rss_content()
    if validEntries:
        attempt = init_client()
        if (attempt):
            response = bluesky_rss_bot(validEntries)
            # Finish by writing the date to file for next run
            with open(CHECK_FILE, 'w') as f:
                f.write(check_date)
                f.close()
            print(response)
    else:
        log_this("Latest blog post already published", False)

if __name__ == "__main__":
    main()
