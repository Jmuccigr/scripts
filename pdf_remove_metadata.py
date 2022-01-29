#!/usr/local/bin/python3

import sys
import pikepdf
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("-k", "--keep", default=False, action="store_true", help = "Keep author and title metadata if present")
parser.add_argument('filename')
parser.add_argument('outputname')
args = parser.parse_args()

# filename = str(sys.argv[1])
# outputname = str(sys.argv[2])
author = ''
title = ''


pdf = pikepdf.open(args.filename)

if args.keep:
	print('here')
	doc = pdf.docinfo

	for key, value in doc.items():
		if key == '/Author':
			author = str(value)
			# print('there is an author:',author)
		elif key == '/Title':
			title = str(value)
			# print('there is a title:',title)


	meta = pdf.open_metadata()

	if author == '':
		try:		
			author = meta['pdf:Author']
		except KeyError:
			try:
				author = meta['dc:creator']
			except KeyError:
				pass

	if title == '':
		try:		
			author = meta['pdf:Title']
		except KeyError:
			try:
				author = meta['dc:title']
			except KeyError:
				pass

try:
	del pdf.docinfo
except KeyError:
	pass
try:
	del pdf.Root.Metadata
except KeyError:
	pass

with pdf.open_metadata(set_pikepdf_as_editor=False) as meta:
	if author != '':
		meta['dc:creator'] = {author}
		# print('author')
	if title != '':
		meta['dc:title'] = title
		# print('title')

pdf.save(args.outputname, fix_metadata_version=False)
