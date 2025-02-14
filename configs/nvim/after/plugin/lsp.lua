--[[
    Lsp.lua - Configure and install the laungage servers
    Last modified: 2024-07-23
]]--

local lsp = require("lsp-zero");

lsp.preset("recommended");

require("mason").setup({});
require("mason-lspconfig").setup({
	ensure_installed = {
		"zls",
		"rust_analyzer",
		"pylsp",
		"rnix",
		"mesonlsp",
		"marksman",
		"lua_ls",
		"kotlin_language_server",
		"jsonls",
		"ts_ls",
		"html",
		"gopls",
		"dockerls",
		"cssls",
		"clangd",
		"cmake",
		"csharp_ls",
		"bashls",
		"awk_ls",
		"asm_lsp",
		"perlnavigator",
		"yamlls",
		"lemminx",
		"taplo",
        "ast_grep"
	},
	handlers = {
		function(server_name)
			require('lspconfig')[server_name].setup({})
		end
	}
});

local cmp = require("cmp");
local cmp_select = {behavior = cmp.SelectBehavior.Select};
local cmp_mappings = lsp.defaults.cmp_mappings({
	["<C-p>"]       = cmp.mapping.select_prev_item(cmp_select),
	["<C-n>"]       = cmp.mapping.select_next_item(cmp_select),
	["<C-Space>"]   = cmp.mapping.confirm({ select = true }),
	["<C-y>"]       = cmp.mapping.complete()
});

cmp.setup({
	mapping = cmp_mappings
});

lsp.on_attach(function(_, buffer_num)
	local opts = {buffer = buffer_num, remap = false};

	vim.keymap.set("n", "gd",           function() vim.lsp.buf.definition() end,        opts);
	vim.keymap.set("n", "K",            function() vim.lsp.buf.hover() end,             opts);
	vim.keymap.set("n", "<leader>vws",  function() vim.lsp.buf.workspace_symbol() end,  opts);
	vim.keymap.set("n", "<leader>vd",   function() vim.diagnostic.open_float() end,     opts);
	vim.keymap.set("n", "[d",           function() vim.diagnostic.goto_next() end,      opts);
	vim.keymap.set("n", "]d",           function() vim.diagnostic.goto_prev() end,      opts);
	vim.keymap.set("n", "<leader>vca",  function() vim.lsp.buf.code_action() end,       opts);
	vim.keymap.set("n", "<leader>vrr",  function() vim.lsp.buf.references() end,        opts);
	vim.keymap.set("n", "<leader>vrn",  function() vim.lsp.buf.rename() end,            opts);
	vim.keymap.set("i", "<C-h>",        function() vim.lsp.buf.signature_help() end,    opts);
    vim.keymap.set("n", "<F3>",         function() vim.lsp.buf.format() end,            opts);
end);

lsp.setup();
