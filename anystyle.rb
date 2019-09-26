require 'anystyle'

v1 = ARGV[0].dup
v2 = v1.force_encoding("UTF-8")

print AnyStyle.parse(v2, format: :bibtex).to_s

exit
