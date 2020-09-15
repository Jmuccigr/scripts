# Some other scripts

Just some other scripts that aren't Apple.

- wikitbl.pl: a perl script that converts simple text tables to wikipedia-style tables.

        SYNOPSIS
        
        wikitbl.pl [-c|-t|-s <text>] [-h] [-help] <input file> [<output file>]
        
        DESCRIPTION

        A script to convert simple text tables to simple Wikipedia-style tables. The
        script assumes that the columns are separated by commas (also can be forced
        by -c), but will accept tabs (-t) and any other string (-s <text>). If the
        -h option is used, the script will treat the first line as a header. No
        effort is made to give all rows an equal number of cells.
        
        The following options are available:
        -c        columns are separated by comma (the default when no option is present)
        -t        columns are separated by tab
        -s <text> columns are separated by <text>
        -h        first row of file is treated as a table header
        -help     print this information
                
        If no output file is indicated, the output will go to STDOUT.
        
    Still to do: provide option for one-line-per-cell style.

- convert_pdf: Use pdfimages to get the right dpi for a PDF and pass that along to convert.

- clean_and_ocr_PDF.sh: replace the OCR in an existing PDF. You can choose to keep the original first page with its text. This leaves the original PDF otherwise the same. Good for cleaning up those JSTOR files with horrible OCR.

- fix_scans.sh: Offers a whole bunch of cleaning options for image files. Good for poor scans.

- ocr_images.sh: Performs OCR on a series of image files and then dumps them all into a single PDF which is scaled to fit on both US Letter and A4 paper (8x10.5" max size).

- zotero_s_and_r.js: a javascript that does a search and replace in Zotero, using the Execute JS add-on for FireFox. See <https://forums.zotero.org/discussion/7707/1/find-and-replace-on-multiple-items/>.
