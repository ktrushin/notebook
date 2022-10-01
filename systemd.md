# systemd

The following is an extremely simplified description of `systemd` with
respect to Unix services (daemons).


Given the service `my_proxy`, one can manage it via `systemctl` commands:
```shell
$ sudo systemctl (enable|start|status|reload|stop|etc) my_proxy
```
if the service file `/lib/systemd/system/my_proxy.service` is provided.
Here are [examples](https://www.shellhacks.com/systemd-service-file-example/)
and the [reference](https://www.freedesktop.org/software/systemd/man/systemd.service.html)
for creating such files.
In addition to a service file, which is usually installed as a part of a deb/rpm
package and should _not_ be changed by an end user, one can put custom
configuration (which inherits settings from the service file) in
`/etc/systemd/system/my_proxy.service.d/` directory. Usually,
the directory contains one file `limits.conf` which emposes the limits on the
system resources the service is allowed to consume. Here are an
[example](https://ma.ttias.be/increase-open-files-limit-in-mariadb-on-centos-7-with-systemd/)
and the [reference](https://www.freedesktop.org/software/systemd/man/systemd.exec.html).

For network services, it may be also beneficial to
[increase](https://www.cyberciti.biz/faq/linux-increase-the-maximum-number-of-open-files/)
system-wide limit on number of concurrently open files.
