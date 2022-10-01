# Docker

Please see more sophisticated examples of docker commands and Dockerfile
in the [ssi](https://github.com/ktrushin/ssi) project:
* [docker/ubuntuu_focal.dockerfile](https://github.com/ktrushin/ssi/blob/master/docker/ubuntu_focal.dockerfile)
* [tools/docker.sh](https://github.com/ktrushin/ssi/blob/master/tools/docker.sh)

Some random command examples:
```shell
docker login <host>:<port>
docker pull <host>:<port>/<path_to_image>:tag
```

Change directory where images and containers are stored:
```shell
$ cat /etc/docker/daemon.json
{
  "data-root": "/depot/root/var/lib/docker/"
}
```

Remove images without containers:
```shell
docker image prune -af
```

Create the image with custom ccache directory
```shell
docker commit --change "ENV CCACHE_DIR=/var/ccache" \
  -m "set up custom ccache directory" e826901cde2a ktrushin/libconfig:1.1
```

Get network's gateway address:
```shell
docker network inspect --format='{{(index .IPAM.Config 0).Gateway}}' <network_name>
```

Dockerfile excerpt for setting up Go programming environment:
```
# Install the latest Golang version
RUN apt-get update && apt-get install --yes --no-install-recommends \
        software-properties-common &&
    add-apt-repository ppa:longsleep/golang-backports && \
    apt-get update && \
    go_pkg_name=\
        $(apt-cache search --names-only '^golang-[1-9][0-9]*\.[0-9][0-9]*$' | \
          sort -t. -k2 -n -r | head -n 1 | cut -f1 -d' ') && \
    apt-get install --yes --no-install-recommends $go_pkg_name

RUN mkdir -p ~/go/{bin,pkg,src}
ENV GOPATH="$HOME/go"
ENV PATH="$PATH:$GOPATH/bin:/usr/lib/$go_pkg_name/bin"
```
