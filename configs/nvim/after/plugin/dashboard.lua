--[[
    Dashboard.lua - Configure the Dashboard plugin
    Last modified: 2024-07-23
]]--

require("dashboard").setup({
    disable_mode = true,

    config = {
        week_header = {
            enable = true,
        },

        footer = {},

        shortcut = {
            { desc = '󰚰 Update', group = '@property', action = 'Lazy update', key = 'u' },
            {
                icon    = ' ',
                desc    = 'Files',
                action  = 'Telescope find_files',
                key     = 'f',
            },
            {
                desc    = ' Projects',
                group   = 'DiagnosticHint',
                action  = function() require('telescope.builtin').find_files { cwd = '~/Projects' } end,
                key     = 'a',
            },
            {
                desc    = ' dotfiles',
                group   = 'Number',
                action  = 'Oil ~/.config',
                key     = 'd',
            },
        },
    }
});
