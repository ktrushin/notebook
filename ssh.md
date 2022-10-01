# ssh

Generate a keypair to be used at `example.com`:
```shell
$ ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_example_com -C "your@email.com"
$ ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa_example_com -C "your@email.com"
```

Note: your email may or may not be on `example.com`.

Please add `-q -N ''` at the end of the shell command above if you want to
generate a key without a passphrase non-interactively.
