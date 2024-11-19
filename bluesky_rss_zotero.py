#!/Users/john_muccigrosso/.venv/bin/python3

# A script to check an RSS feed and share the latest new entry on Bluesky.
# Guts of it are from <https://sperea.es/blog/bot-bluesky-rss>.
# I added in the required createdAt and also pushed some constants into
# files for privacy.

import feedparser
import urllib3
import json
import os.path
from datetime import datetime, timezone
import time
import sys
import re

# Constants
CHECK_FILE = "zotero_date.txt"
BLUESKY_PW_FILE = "bluesky_app_password.txt"
BLUESKY_HANDLE_FILE = "bluesky_handle.txt"
MAX_POSTS = 3
# In this case I can limit the length of the returned feed 
FEED_URL = "https://api.zotero.org/users/493397/items/top?start=0&limit=" + MAX_POSTS.__str__() + "format=atom&v=3"
BLUESKY_API_ENDPOINT = "https://bsky.social/xrpc/com.atproto.repo.createRecord"
DELAY = 5 #in seconds

def compare_post_dates(post_date, check_file):
    global pubdate

    # If not already done, check the file for the lastest published date.
    # Report error & set an absurdly early date if the file doesn't exist
    if pubdate == "":
        if not os.path.isfile(check_file):
            pubdate="1900-01-01T00:00:01+00:00"
            with open(check_file, 'x') as file:
                file.write(pubdate)
            print(timestamp + "Zotero item check file does not exist", file=sys.stderr)
        else:
            # Open the file and read the date of the last published Zotero item.
            f = open(check_file, "r")
            pubdate = f.readlines()[0].replace("\n", "")

    latest_post_date = datetime.strptime(post_date, "%Y-%m-%dT%H:%M:%S%z")
    last_published_date = datetime.strptime(pubdate, "%Y-%m-%dT%H:%M:%S%z")
    if latest_post_date > last_published_date:
        return latest_post_date  # latest post is newer
    else:
        return False # last published is newer

def get_did():
    http = urllib3.PoolManager()
    DID_URL = "https://bsky.social/xrpc/com.atproto.identity.resolveHandle"
    did_resolve = http.request("GET", DID_URL, fields={"handle": handle})
    return json.loads(did_resolve.data)["did"]

def get_api_key(did, app_password):
    http = urllib3.PoolManager()  # Initializes a pool manager for HTTP requests
    API_KEY_URL = "https://bsky.social/xrpc/com.atproto.server.createSession"  # The endpoint to request the API key

    # Data to be sent to the server
    post_data = {
        "identifier": did,  # The user's DID
        "password": app_password  # The app password generated earlier
    }

    headers = {
        "Content-Type": "application/json"  # Specifies the format of the data being sent
    }

    # Send a POST request with the required data to obtain the API key
    api_key_response = http.request("POST", API_KEY_URL, headers=headers, body=json.dumps(post_data))

    # Parse the response to extract the API key
    return json.loads(api_key_response.data)["accessJwt"]

def get_rss_content():

    ct=0
    # Parse the RSS feed
    feed = feedparser.parse(FEED_URL)

    validEntries=[]
    # Iterate through the entries in the feed until we have enough or they're exhausted
    max_posts=min(MAX_POSTS, len(feed.entries))
    for entry in feed.entries:
        if ct < max_posts:
            post_title = entry.title
            post_link = entry.link
            # Using published time, but updated time might be better in some situations
            post_date = entry.published
            response=compare_post_dates(post_date, check_file)
            if response:
                ct += 1
                temp = dict()
                temp["title"] = post_title
                temp["link"] = post_link
                validEntries.append(temp)
    # You can further expand this by including other details like the post's published date,
    # author, summary, etc., depending on your needs.

    #return latest_post_title, latest_post_link, latest_post_date
    if ct > 0:
        return validEntries
    else:
        return False

def prepare_post_for_bluesky(title, link):
    """Convert the RSS content into a format suitable for Bluesky."""

    global now
    
    # The post's body text
    post_text = f"Recently noted...\n\n{title}\n\nin my Zotero library: {link}"

    # The post structure for Bluesky
    post_structure = {
        "text": post_text,
        "embed": {
            "$type": "app.bsky.embed.links",   # Bluesky's format for embedding links
            "links": [link]
        },
        "createdAt": now
    }

    return post_structure

def publish_on_bluesky(post_structure, did, key):
    """Publish the structured post on Bluesky."""

    http = urllib3.PoolManager()   # Initializes a pool manager for HTTP requests
    post_feed_url = BLUESKY_API_ENDPOINT  # The endpoint to post on Bluesky

    # The complete record for the Bluesky post, including our structured content
    post_record = {
        "collection": "app.bsky.feed.post",
        "repo": did,    # The unique DID of our account
        "record": post_structure

    }

    headers = {
        "Content-Type": "application/json",       # Specifies the format of the data being sent
        "Authorization": f"Bearer {key}"          # The API key for authenticated posting
    }

    # Send a POST request to publish the post on Bluesky
    post_request = http.request("POST", post_feed_url, body=json.dumps(post_record), headers=headers)

    # Parse the response for any necessary information, such as post ID or confirmation status
    response = json.loads(post_request.data)

    return response

def bluesky_rss_bot(app_password, check_file):
    # Fetch content from the RSS feed
    validEntries = get_rss_content()
    # Only do something if there are valid entries
    if validEntries:
        # Authenticate and obtain necessary credentials
        did = get_did()
        key = get_api_key(did, app_password)
        ct=0
        # Prepare the fetched content for Bluesky
        for entry in validEntries:
            # Wait a little if posting more than one entry
            if ct > 0:
                time.sleep(DELAY)
            ct += 1
            post_structure = prepare_post_for_bluesky(entry['title'], entry['link'])
            # Publish the content on Bluesky
            bluesky_reply = publish_on_bluesky(post_structure, did, key)
        print(timestamp + " Published latest Zotero items to Bluesky", file=sys.stderr)
        return bluesky_reply
    else:
        print(timestamp + " Latest Zotero item already published", file=sys.stderr)
        return "No need to post."

def main():
    global now
    global check_file
    global handle
    global timestamp
    global pubdate

    pubdate=""

    # Get a timestamp for log entries
    now=datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    timestamp =(f'{datetime.now():%Y-%m-%d %H:%M:%S%z}')
    check_date=datetime.now(timezone.utc).isoformat(sep='T', timespec='seconds')
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
        response = bluesky_rss_bot(app_pw, check_file)
        # Finish by writing the date to file for next run
        with open(check_file, 'w') as f:
            f.write(check_date)
#         print( response)

if __name__ == "__main__":
    main()

# Success: {'uri': 'at://did:plc:mocpqererjufnog5yrnijjeq/app.bsky.feed.post/3lb7u64vnsy2p', 'cid': 'bafyreiez74qeannl4an7rv6gbwfln2goi6plkh6peaqdw7vv3mksljxck4', 'commit': {'cid': 'bafyreicqvwxxwexcnegn4gqmebqo334f6zc2znsinlintkgijglbeii5ym', 'rev': '3lb7u64vspa2p'}, 'validationStatus': 'valid'}
