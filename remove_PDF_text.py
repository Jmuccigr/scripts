#!/opt/homebrew/bin/python3
import sys
from pypdf import PdfWriter, PdfReader
output = PdfWriter()

filename = str(sys.argv[1])
outputname = str(sys.argv[2])

ipdf = PdfReader(open(filename, 'rb'))

#for i in range(ipdf.getNumPages()):
for i in range(len(ipdf.pages)):
	page = ipdf.pages[i]
	output.add_page(page)
	output.remove_text

with open(outputname, 'wb') as f:
   output.write(f)
