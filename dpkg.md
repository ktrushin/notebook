# dpkg

List files in a package
```shell
dpkg -c <package_name>.deb
dpkg -L <package_name>
```

Find which package provides a file
```shell
dpkg -S /path/to/file
```

Get package info:
```shell
dpkg --info <package_name>.deb
```

List installed packages whose names contain `foo`:
```shell
dpkg -l '*foo*' | grep '^ii'
```

Post removal and post installation scripts are located at `/var/lib/dpkg/info`.
