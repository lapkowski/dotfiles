--[[
    Telescope.lua - Configure the telescope fuzzy finder
    Last modified: 2024-07-23
]]--

local builtin = require("telescope.builtin");
vim.keymap.set("n", "<leader>pf",       builtin.find_files, {});
vim.keymap.set("n", "<leader><leader>", builtin.git_files, {});
vim.keymap.set("n", "<leader>ps",       function() builtin.grep_string({ search = vim.fn.input("(Grep) ") }); end);
