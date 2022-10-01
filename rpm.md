# RPM

Install the package but don't touch the updated files:
```shell
$ rpm -Uvh <path_to_rpm_file>
```

List files in a package
```shell
rpm -ql <package_name>
rpm -qpl <package_name>.rpm
```

Find the (installed) package a file belongs to:
```shell
rpm -qf /path/to/the/file
```

List package dependencies
```shell
$ rpm -qpR /path/to/package.rpm
$ repoquery --requires <package_name>
$ repoquery --requires --resolve <package_name>
```

List package conflicts:
```shell
$ rpm -qp --conflicts /path/to/package.rpm
```

List package changelog:
```shell
$ rpm -qp --changelong /path/to/package.rpm
```

List package info
```shell
$ rpm -qp --info /path/to/package.rpm
```

More options on the [man page](https://man7.org/linux/man-pages/man8/rpm.8.html)
