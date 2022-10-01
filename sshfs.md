# sshfs

```shell
$ sudo apt-get install sshfs
```
If command
```shell
$ cat /etc/group | grep 'fuse'
```
shows nothing, then run
```shell
$ sudo groupadd fuse
$ sudo usermod -a -G fuse $USER
```
Restart the machine.

Mount/unmount:
```shell
$ sshfs -o idmap=user $USER@remote_host:/ /some/local/path/remote_host
$ fusermount -u /some/local/path/remote_host
```
