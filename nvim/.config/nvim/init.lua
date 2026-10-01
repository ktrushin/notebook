vim.opt.clipboard:append("unnamedplus")

require('kitty-scrollback').setup({
  {
    paste_window = {
      highlight_as_normal_win = true,
    },
    visual_selection_highlight_mode = 'kitty',
  }
})

-- Make Neovim background match terminal background
vim.cmd([[
  highlight Normal guibg=NONE ctermbg=NONE
  highlight NonText guibg=NONE ctermbg=NONE
  highlight Normal ctermbg=NONE
]])
