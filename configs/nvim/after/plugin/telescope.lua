--[[
    Telescope.lua - Configure the telescope fuzzy finder
    Last modified: 2024-07-23
]]--

require("telescope").load_extension("aerial");
require("telescope").setup({
  extensions = {
    aerial = {
      -- Set the width of the first two columns (the second
      -- is relevant only when show_columns is set to 'both')
      col1_width = 4,
      col2_width = 30,
      -- How to format the symbols
      format_symbol = function(symbol_path, filetype)
        if filetype == "json" or filetype == "yaml" then
          return table.concat(symbol_path, ".")
        else
          return symbol_path[#symbol_path]
        end
      end,
      -- Available modes: symbols, lines, both
      show_columns = "both",
    },
  },
});

local builtin = require("telescope.builtin");
vim.keymap.set("n", "<leader>pf",       builtin.find_files, {});
vim.keymap.set("n", "<leader><leader>", builtin.git_files, {});
vim.keymap.set("n", "<leader>ps",       function() builtin.grep_string({ search = vim.fn.input("(Grep) ") }); end);
vim.keymap.set("n", "<leader>pd",       require("telescope").extensions.aerial.aerial, {});
