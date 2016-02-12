# Some other scripts

Just some other scripts that aren't Apple.

- wikitbl.pl: a perl script that converts simple text tables to wikipedia-style tables. Syntax:

        wikitbl.pl -c|-t|-s <separator> [-h] <input file> [<output file>]
        
        -c : columns are separated by comma (the default when no option is present)
        -t : columns are separated by tab
        -s <separator>: columns are separated by <separator>
        -h : first row of file is treated as a table header
        
        If no output file is indicated, the output will go to STDOUT.
        
    Still to do: provide option for one-line-per-cell style.
