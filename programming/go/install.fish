#!/usr/bin/env fish

# Define your custom locations
set -l goroot "$HOME/.local/go"
# As per the XDG Base Directory spec, `~/.local/share` is explicitly meant for
# persistent application data
set -l gopath "$HOME/.local/share/go"

# Fetch latest stable version and install into custom GOROOT
set -l gov (curl -fsSL 'https://go.dev/VERSION?m=text' | head -n1)
and curl -fsSLO "https://go.dev/dl/$gov.linux-amd64.tar.gz"
and mkdir -p $goroot
and tar -C $goroot --strip-components=1 -xzf "$gov.linux-amd64.tar.gz"
and rm "$gov.linux-amd64.tar.gz"

# Persist GOROOT, GOPATH, and PATH entries as universal variables
set -Ux GOROOT $goroot
set -Ux GOPATH $gopath
mkdir -p $gopath/bin
fish_add_path $goroot/bin
fish_add_path $gopath/bin
