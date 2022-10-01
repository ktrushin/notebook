# dnf

Random examples:
```shell
$ dnf install -y vim
$ dnf remove vim
$ dnf info vim
$ dnf autoremove
```

List pacakges:
```shell
$ dnf list avalable
$ dnf list installed
$ dnf list <package name>
$ dnf list <regex>
$ dnf list *libconfig*
$ dnf --showduplicates list <package name>
$ dnf whatprovides /bin/ps
```

Find the package with provides the file:
```shell
$ dnf whatprovides /bin/ps
$ dnf provides /bin/ps
```

List files in a package
```shell
repoquery -l <my_package>
repoquery -l vim
```

Downgrade a package:
```shell
$ dnf downgrade httpd-2.2.3-22.el5
```

Upgrade a package:
```shell
$ dnf update httpd-2.2.3
```

Update package cache:
```shell
S sudo dnf check-update
```

Execute a command without checking network repos:
```shell
$ sudo dnf -C <command>
$ sudo dnf -C --showduplicates gcc
```

Clean the cache. That is sometimes helpful to get just uploaded packages.
```shell
dnf clean all
```
