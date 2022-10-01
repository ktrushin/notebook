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

Add the following to the `~/.config/kitty/kitty.conf` file:
```
font_family      Ubuntu Mono
bold_font        Ubuntu Mono Bold
italic_font      Ubuntu Mono Italic
bold_italic_font Ubuntu Mono Bold Italic
font_size 13

include ./theme.conf

enable_audio_bell no

allow_remote_control yes

enabled_layouts splits, grid, tall, vertical

map ctrl+alt+enter launch --cwd=current
map ctrl+alt+v     launch --cwd=current --location=vsplit
map ctrl+alt+h     launch --cwd=current --location=hsplit

scrollback_lines 8192
scrollback_pager bash -c "exec nvim 63<&0 0</dev/null -u NONE -c 'map <silent> q :qa!<CR>' -c 'set shell=bash scrollback=100000 termguicolors laststatus=0 clipboard+=unnamedplus' -c 'autocmd TermEnter * stopinsert' -c 'autocmd TermClose * call cursor(max([0,INPUT_LINE_NUMBER-1])+CURSOR_LINE, CURSOR_COLUMN)' -c 'terminal sed </dev/fd/63 -e \"s/'$'\x1b'']8;;file:[^\]*[\]//g\" && sleep 0.01 && printf \"'$'\x1b'']2;\"' -c 'autocmd VimLeave * call system(\"xclip -o -selection c | xclip -selection c\")'"

shell_integration no-cursor no-title

touch_scroll_multiplier 5.0

linux_display_server x11
wayland_titlebar_color background
```

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
