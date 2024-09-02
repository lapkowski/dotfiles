--[[
    Textobjects.lua - Configure treesitter-based launguage element keymaps
    Last modified: 2024-07-23
]]--

require('nvim-treesitter.configs').setup({
  textobjects = {
    select = {
      enable = true,

      lookahead = true,

      keymaps = {
        ["af"] = "@function.outer",
        ["if"] = "@function.inner",
        ["ac"] = "@class.outer",
        ["ic"] = { query = "@class.inner", desc = "Select inner part of a class region" },
        ["as"] = { query = "@scope", query_group = "locals", desc = "Select language scope" }
      },
      selection_modes = {
        ['@parameter.outer']    = 'v',
        ['@function.outer']     = 'V',
        ['@class.outer']        = '<c-v>'
      },
      include_surrounding_whitespace = true,
    },
    move = {
      enable = true,
      set_jumps = true,
      goto_next_start = {
        ["]c"] = { query = "@class.outer", desc = "Next class start" },
        ["]]"] = "@function.outer",
        ["]o"] = "@loop.*",
        ["]s"] = { query = "@scope", query_group = "locals", desc = "Next scope" },
        ["]z"] = { query = "@fold", query_group = "folds", desc = "Next fold" }
      },
      goto_next_end = {
        ["]["] = "@function.outer",
        ["]C"] = "@class.outer"
      },
      goto_previous_start = {
        ["[["] = "@function.outer",
        ["[c"] = "@class.outer"
      },
      goto_previous_end = {
        ["[]"] = "@function.outer",
        ["[C"] = "@class.outer"
      },
      goto_next = {
        ["]d"] = "@conditional.outer"
      },
      goto_previous = {
        ["[d"] = "@conditional.outer"
      }
    }
  }
});
