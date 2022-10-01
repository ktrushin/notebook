# General

## Source code clean-up
Remove trailing whitespaces and unnecessary multiple newlines
at the end of the files in a git repo
```shell
$ find . -not -wholename "./.git" -not -wholename "./.git/*" \
-not -wholename "./path/to/exclude1" \
-not -wholename "./path_to_exclude_2" -type f \
-exec sed -i 's/[ \t]\{1,\}$//' {} \;
$
$ find . -not -wholename "./.git" -not -wholename "./.git/*" \
-not -wholename "./path/to/exclude1" \
-not -wholename "./path_to_exclude2" -type f \
-exec sed -i -e :a -e '/^\n*$/{$d;N;};/\n$/ba' {} \;
```
