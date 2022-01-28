#!/usr/local/bin/python3

import sys
from PyPDF2 import PdfFileWriter, PdfFileReader
output = PdfFileWriter()

filename = str(sys.argv[1])
outputname = str(sys.argv[2])

ipdf = PdfFileReader(open(filename, 'rb'))

for i in range(ipdf.getNumPages()):
	page = ipdf.getPage(i)
    for img in page.getPageImageList(i):
    	page =
	output.addPage(page)
	output.removeText(i)

with open(outputname, 'wb') as f:
   output.write(f)

