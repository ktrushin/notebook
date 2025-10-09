# C++

See C++ builtin specs for GCC:
```shell
$ echo | gcc -xc++ -E -v -
```

Core pattern
```shell
$ man core
$ echo '/var/core/core.%e.%t.%p.%i' | sudo tee /proc/sys/kernel/core_pattern
```

ABI tools (apt packages):
- abi-compliance-checker
- abi-dumper
- abi-monitor
- abi-tracker
- abicheck
- abigail-tools

When debugging an executable linked against shared libraries, those libraries
(and their debug symbols) are loaded only when the executable is run. Hense,
the symbols (and files) are unavailable before the the gdb `run` command is
executed, and it is impossible to set a breakpoint to location in the shared
libraries. To work around that issue, set a breakpoint to the `main` function,
then execute the gdb `run` command. When the execution of the inferior process
stops at the breakpont, the dynamic libraries have been already loaded, so now
one can set a breakpont on a location in a dynamic library.

## readelf
See the dynamic section (that includes list of needed dynamic libraries and
rpath):
```shell
$ readelf -d path/to/my/lib_or_executable
```

See the symbols in a dynamic library:
```shell
$ readelf --dyn-syms --demangle --wide path/to/my/libfoo.so
```
