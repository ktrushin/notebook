# GDB

## Trick to set a breakpoint to a location in a shared library
When a binary is linked dynamically, the debug symbols from its shared libraries
aren't available until the binary is run. We set a breakpoint to the `main`
function. When the execution flow hits it, all shared libraries (with their
debug symbols) have been already loaded. At this point, we can set breakpoints
to the code in shared libraries using different location specifiers.
```
$ gdb --args path/to/the/binary arg0 arg1 arg2
(gdb) break main
(gdb) run
Breakpoint 1.1 maiin(...
(gdb) break <path/to/shared/library/source.cpp>:<line_number>
(gdb) break <function_from_a_shared_library>
(gdb) continue
```

## Debug symbols and source code location
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
On Ubuntu, default value for `<path_to_the_debug_symbols_directory>` is
`/usr/lib/debug`
For more info, please see:
- https://sourceware.org/gdb/current/onlinedocs/gdb.html/Files.html
- https://sourceware.org/gdb/current/onlinedocs/gdb.html/Source-Path.html

The following example debug the `einfo` executable with the `-h` option. The
executable is from the `epub-utils` binary package, which in turn is built from
the `ebooks-tools` source package. The `ebook-tools-dbg` package places the
debug symbols in the `/usr/lib/debug` directory
```
$ sudo apt-get update && sudo apt-get install epub-utils ebook-tools-dbg
$ mkdir /tmp/soruce_pkgs
$ cd /tmp/soruce_pkgs
$ apt-get source ebook-tools
$ gdb
(gdb) set debug-file-directory /usr/lib/debug
(gdb) directory /tmp/soruce_pkgs/ebook-tools-0.2.2/
(gdb) file /usr/bin/einfo
Reading symbols from /usr/bin/einfo...
Reading symbols from /usr/lib/debug/.build-id/e9/2d9fd3ec4cb522c5ce4c79b9b58b634ccbddd8.debug...
(gdb) set args -h
(gdb) break main
Breakpoint 1 at 0x11e0: file ./src/tools/einfo.c, line 26.
(gdb) run
Starting program: /usr/bin/einfo -h
[Thread debugging using libthread_db enabled]
Using host libthread_db library "/lib/x86_64-linux-gnu/libthread_db.so.1".

Breakpoint 1, main (argc=2, argv=0x7fffffffe418) at ./src/tools/einfo.c:26
26  int main(int argc , char **argv) {
(gdb)
(gdb)
(gdb) list
21   fprintf(stderr, "   -t <tour id>\t prints the tour <tour id>\n");
22
23   exit(code);
24  }
25
26  int main(int argc , char **argv) {
27   struct epub *epub;
28   char *filename = NULL;
29   char *tourId = NULL;
30   int verbose = 0, print = 0, debug = 0, quiet = 0, tour = 0;
(gdb)
```
