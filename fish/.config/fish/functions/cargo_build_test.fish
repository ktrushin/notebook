function cargo_build_test --description 'Run cargo build and test' --argument-names testname
    cargo fmt --all --check && cargo check --all-targets && \
            cargo clippy --no-deps --all-targets -- -D warnings && cargo test $testname
end
