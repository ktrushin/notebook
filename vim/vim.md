# vim

## Integrate copying and pasting with the clipboard
Install the `vim-gtk3` (or `vim-gnome`) package:
```shell
sudo apt-get install -y vim-gtk3
```
Make sure `vim` now has the clipboard support:
```vim
: echo has('clipboard')
1
```
Make plain `y`, `d` and `p` use the system clipboard. Add the following to your `~/.vimrc`:
```vim
set clipboard=unnamedplus
```
