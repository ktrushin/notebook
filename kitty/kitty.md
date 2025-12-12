# Kitty terminal emulator

## Installation and Configuration
Install kitty and neovim; download themes and set up the `monokai` theme
```shell
$ sudo apt-get install kitty neovim
$ git clone --depth 1 git@github.com:dexpota/kitty-themes.git ~/.config/kitty/kitty-themes
$ ln -s ~/.config/kitty/kitty-themes/themes/Monokai.conf ~/.config/kitty/theme.conf
```

Install [kitty-scrollback.nvim][ksb-install] (see `Using Neovim's built-in
package support pack`)
```shell
$ mkdir -p "$HOME/.local/share/nvim/site/pack/mikesmithgh/start/"
$ cd $HOME/.local/share/nvim/site/pack/mikesmithgh/start
$ git clone git@github.com:mikesmithgh/kitty-scrollback.nvim.git
$ nvim -u NONE -c "helptags kitty-scrollback.nvim/doc" -c q
$ mkdir -p "$HOME/.config/nvim"
$ echo "require('kitty-scrollback').setup()" >> "$HOME/.config/nvim/init.lua"
```
Generate the kitten mappings. Add the result of the following command to the
kitty configuration file (the configuration file `kitty.conf` already includes
that)
```shell
$ nvim --headless +'KittyScrollbackGenerateKittens'
...
```

Copy the `kitty.conf` file to the `~/.config/kitty/` directory.
Copy the `init.lua` file to the `~/.config/nvim/` directory.
Completely close and reopen Kitty

Check the health of kitty-scrollback.nvim
```shell
nvim +'KittyScrollbackCheckHealth'
```
Follow the instructions of any `ERROR` or `WARNINGS` reported during the
healthcheck.

## Support
If you encournter the `"terminal is not fully functional"` warning (for instance,
in a Docker constainer's bash shell), install the `kitty-terminfo` package
(in the container)
```shell
$ sudo apt-get install kitty-terminfo
```
Alternatively, you can do the following. On the host machine:
```shell
$ infocmp xterm-kitty > kitty.terminfo
```
Then, in the container:
```
$ tic kitty.terminfo
```
Ignore the `older tic versions may treat the description field as an alias` error if any.
Exit from a container's shell and run the shell in the container again:
```shell
$ docker container exec -it <container_name> bash
```
Now, everything should work.

## Archive
Old scrollback pager recipes for `kitty.conf`:
```
scrollback_pager bash -c "exec nvim 63<&0 0</dev/null -u NONE -c 'map <silent> q :qa!<CR>' -c 'set shell=bash scrollback=100000 termguicolors laststatus=0 clipboard+=unnamedplus' -c 'autocmd TermEnter * stopinsert' -c 'autocmd TermClose * call cursor(max([0,INPUT_LINE_NUMBER-1])+CURSOR_LINE, CURSOR_COLUMN)' -c 'terminal sed </dev/fd/63 -e \"s/'$'\x1b'']8;;file:[^\]*[\]//g\" && sleep 0.01 && printf \"'$'\x1b'']2;\"'"
scrollback_pager /usr/bin/nvim -u NONE -c "set nonumber nolist showtabline=0 foldcolumn=0 laststatus=0" -c "autocmd TermOpen * normal G" -c "map q :qa!<CR>" -c "set clipboard+=unnamedplus" -c "silent write! /tmp/kitty_scrollback_buffer | te echo -n \"$(cat /tmp/kitty_scrollback_buffer)\" && sleep 1000 "
```

Alternative method for kitty installation:
```shell
$ curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin
$ sudo ln -s ~/.local/kitty.app/bin/kitty /usr/bin/kitty
```
Alternative way of fixing the `"terminal is not fully functional"` warning is
copying terminfo files (if they exist) to the system directory (e.g. in the
Docker container shell)
```shell
$ sudo cp -a "${TERMINFO:-$HOME/.terminfo}"/* /etc/terminfo/
```


[ksb-install]: https://github.com/mikesmithgh/kitty-scrollback.nvim/tree/main?tab=readme-ov-file#-installation
