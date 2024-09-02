--[[
    Colorscheme.lua - Configure the kanagawa colorscheme
    Last modified: 2024-07-23
]]--

require('kanagawa').setup({
	colors = {
	    theme = {
            all = {
                ui = {
                bg_gutter = "none"
                }
            }
	    }
	}
});

colorschemes = { "kanagawa-wave", "kanagawa-dragon", "kanagawa-lotus" };
current_colorscheme = 1; -- The default one

cycle_through_colorschemes = function()
	current_colorscheme = (current_colorscheme == #colorschemes) and 1 or current_colorscheme + 1;

	vim.cmd("colorscheme "..colorschemes[current_colorscheme]);
end

vim.keymap.set("n", "<leader>m", cycle_through_colorschemes);
