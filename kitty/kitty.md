# Kitty terminal emulator

Install kitty
```shell
$ curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin
$ sudo ln -s ~/.local/kitty.app/bin/kitty /usr/bin/kitty
```

Install themes
```shell
$ git clone --depth 1 git@github.com:dexpota/kitty-themes.git ~/.config/kitty/kitty-themes
$ ln -s ~/.config/kitty/kitty-themes/themes/Monokai.conf ~/.config/kitty/theme.conf
```

Install neovim
```shell
$ sudo apt-get install neovim
```

Copy the `kitty.conf` file to the `~/.config/kitty/` directory.

From a Kitty terminal window, execute the following:
```shell
$ sudo cp -a "${TERMINFO:-$HOME/.terminfo}"/* /etc/terminfo/
```
That can eliminate the "terminal is not fully functional" warnings when using
`systemctl`, for instance.

JFR: old scrollback pager recipe:
```
scrollback_pager /usr/bin/nvim -u NONE -c "set nonumber nolist showtabline=0 foldcolumn=0 laststatus=0" -c "autocmd TermOpen * normal G" -c "map q :qa!<CR>" -c "set clipboard+=unnamedplus" -c "silent write! /tmp/kitty_scrollback_buffer | te echo -n \"$(cat /tmp/kitty_scrollback_buffer)\" && sleep 1000 "
```
