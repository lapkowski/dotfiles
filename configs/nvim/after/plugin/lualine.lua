--[[
    Lualine.nvim - Configure the look of the status line.
    Based on: https://github.com/Tibor5/minim_lualine
    Last modified: 23-07-2024
]]--

local theme = require("kanagawa.colors").setup({ theme = "wave" }).theme;
local has_devicons, devicons = pcall(require, "nvim-web-devicons");
local static = {}

local custom_icons = {
    git_branch      = "",
    error           = " ",
    warn            = " ",
    info            = " ",
    hint            = " ",
    added           = " ",
    modified        = "󰝤 ",
    modified_simple = "~ ",
    removed         = " ",
    lock            = "",
    touched         = "●"
}

local get_ftype_icon = function ()
    if not has_devicons then return end

    local full_filename     = vim.api.nvim_buf_get_name(0);
    local filename          = vim.fn.fnamemodify(full_filename, ":t");
    local extension         = vim.fn.fnamemodify(filename, ":e");

    static.ftype_icon, static.ftype_icon_color = devicons.get_icon_color(filename, extension, { default = true });

    return static.ftype_icon and static.ftype_icon .. "";
end

condition = {};

condition.is_buf_empty = function()
    return vim.fn.empty(vim.fn.expand("%t:t")) ~= 1
end

condition.is_git_repo = function()
    local filepath  = vim.fn.expand("%:p:h")
    local gitdir    = vim.fn.finddir(".git", filepath .. ";")

    return gitdir and #gitdir > 0 and #gitdir < #filepath
end

require("lualine").setup({
    extensions = {
        "aerial"
    },
    options = {
        component_separators = "",
        section_separators = "",
        always_divide_middle = true,
        theme = "auto"
    },
    sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = {
            {
                function() return "| " end,
                color   = { fg = theme.ui.fg_dim },
                padding = { left = 0 }
            },
            {
                get_ftype_icon,
                color   = { fg = static.ftype_icon_color },
                padding = { left = 0, right = 1 }
            },
            {
                "filename",
                path = 0,
                symbols = {
                    modified    = custom_icons.touched,
                    readonly    = custom_icons.lock,
                    unnamed     = "[No Name]",
                    newfile     = "[New]"
                }
            },
            {
                "aerial",
                sep       = " ",
                depth     = nil,
                dense     = false,
                dense_sep = ".",
                colored   = true,
            }
        },
        lualine_x = {
            {
                "diff",
                cond = condition.is_git_repo,
                source = function()
                    if not vim.b.gitsigns_status_dict then return end

                    return {
                        added       = vim.b.gitsigns_status_dict.added,
                        modified    = vim.b.gitsigns_status_dict.changed,
                        removed     = vim.b.gitsigns_status_dict.removed
                    }
                end,
                symbols = {
                    added       = custom_icons.added,
                    modified    = custom_icons.modified_simple,
                    removed     = custom_icons.removed
                },
                colored = true,
                diff_color = {
                    added       = { fg = theme.vcs.added },
                    modified    = { fg = theme.vcs.changed },
                    removed     = { fg = theme.vcs.removed }
                }
            },
            {
                "diagnostics",
                sources = { "nvim_lsp", "nvim_diagnostic" },
                symbols = {
                    error   = custom_icons.error,
                    warn    = custom_icons.warn,
                    info    = custom_icons.info,
                    hint    = custom_icons.hint
                },
                diagnostics_color = {
                    error   = { fg = theme.diag.error },
                    warn    = { fg = theme.diag.warning },
                    info    = { fg = theme.diag.info },
                    hint    = { fg = theme.diag.hint }
                }
            },
            {
                "branch",
                icon    = custom_icons.git_branch,
                color   = { fg = theme.syn.parameter }
            },
            {
                "location",
                color   = { fg = theme.ui.fg_dim }
            },
            {
                function() return " |" end,
                color   = { fg = theme.ui.fg_dim },
                padding = { right = 0 }
            }
        },
        lualine_y = {},
        lualine_z = {},
    },
    inactive_sections = {
        lualine_a = { "filename" },
        lualine_b = { "location" }
    }
});

require("lualine").hide({place = {"tabline"}});
