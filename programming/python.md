# Python

## UV
Upgrade Python to new version
```shell
$ uv python list
$ uv python pin 3.14
$ uv lock --upgrade
$ uv sync
```

Upgrade a dependency to the latest version
Use `pytest` as an example:
```shell
$ uv add --dev 'pytest>=9.0.3'
```

## Misc
The `pip3` tool installs packages into the
`/usr/local/lib/python3.8/dist-packages` directory.

Installing a local project from source:
```shell
pip3 install /path/to/the/project
```
where the `/path/to/the/project` directory contains the `setup.py` script.
Installing a local project in development (editable) mode:
```shell
pip3 install -e /path/to/the/project
```

Typical list of Python packages for development in Python:
- setuptools
- wheel
- twine
- flake8
- flake8-docstring-checker
- pytest-flake8 or flake8-pytest
- mypy
- pylint
- pylint-doc-spacing
- pytest
- nox
- tox
- tox-delay
