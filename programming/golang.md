# Golang

Installing golang:
```shell
$ set -Ux GOROOT="$HOME/.go"
$ set -Ux GOPATH="$HOME/.local/go"
$ wget -q -O - https://git.io/vQhTU | bash
```
Please see https://github.com/canha/golang-tools-install-script for more details.

```shell
$ gofmt -l -w .
$ go mod tidy -v
$ go build -o <my_binary_name> -ldflags "-X main.version=v0.0.1" .
$ go test ./...
```
