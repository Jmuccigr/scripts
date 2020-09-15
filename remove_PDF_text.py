#!/usr/local/bin/python3

from PyPDF2 import PdfFileWriter, PdfFileReader
import sys
output = PdfFileWriter()

filename = str(sys.argv[1])
outputname = str(sys.argv[2])

ipdf = PdfFileReader(open(filename, 'rb'))

for i in range(ipdf.getNumPages()):
	page = ipdf.getPage(i)
	output.addPage(page)
	output.removeText(i)

with open(outputname, 'wb') as f:
   output.write(f)

