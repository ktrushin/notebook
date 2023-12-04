# GDB

Debugging a program with nondefault locations of debugging symbols and source
code:
```
$ gdb
(gdb) set debug-file-directory <path_to_the_debug_symbols_directory>
(gdb) show debug-file-directory
(gdb) directory <path_to_the_source_directory>
(gdb) show directories
(gdb) file <path_to_the_executable>
Reading symbols from <path_to_the_debug_symbols_directory>/.build-id/5b/877dcd5360292c5060a70e61206c183881401f.debug
(gdb) set args --foo=bar -b norf
(gdb) break main
(gdb) run
```
For more info, please see:
- https://sourceware.org/gdb/current/onlinedocs/gdb.html/Files.html
- https://sourceware.org/gdb/current/onlinedocs/gdb.html/Source-Path.html
