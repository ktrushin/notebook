# Rust

## Basic Compiling and Testing
Define a shell function that checks the source code formatting, does linting,
and runs tests.
In the Fish shell:
```fish
$ function cargo_build_test --description "Run cargo build and test" --argument-names testname
    cargo fmt --all --check && cargo check --all-targets && \
    cargo clippy --no-deps --all-targets -- -D warnings && cargo test $testname
  end
$ funcsave cargo_build_test
$ abbr -a cbt cargo_build_test
```
In Bash:
```bash
cargo_build_test() {
  cargo fmt --all --check && cargo check --all-targets && \
  cargo clippy --no-deps --all-targets -- -D warnings && cargo test $1
}
```
Usage:
```
$ cargo_build_test
$ cargo_build_test sort
$ cargo_build_test sort::tests::test_insertion
```

## Run a Unit Test under a Debugger:
```fish
$ cargo test --verbose sort::tests::test_insertion
...
Running `<project_root_dir>/target/debug/deps/clay-ed091d8947ee2f17 'sort::tests::test_insertion'`
...
$
$ rust-gdb --args target/debug/deps/clay-ed091d8947ee2f17 'sort::tests::test_insertion'
(gdb) break main
(gdb) quit
$
$ rust-lldb -- target/debug/deps/clay-ed091d8947ee2f17 'sort::tests::test_insertion'
(lldb) breakpoint set --name main
(lldb) quit
```
