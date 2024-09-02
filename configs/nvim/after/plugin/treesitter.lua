--[[
    Treesitter.lua - Configure the treesitter
    Last modified: 2024-07-23
]]--

require('nvim-treesitter.configs').setup({
  ensure_installed = { "c", "lua", "vim", "vimdoc", "query", "markdown", "markdown_inline", "zig", "rust", "nix", "make" },

  sync_install = false,
  auto_install = true,

  highlight = {
    enable = true,

    additional_vim_regex_highlighting = false
  }
});
