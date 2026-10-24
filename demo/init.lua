-- Config the README demo is recorded with (`make demo`), in a sandbox under
-- .demo/ with its own stdpaths. morrow.nvim colors, ui2 messages and a
-- plain 'statusline'.

local root = vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2)))
-- Only inside the `make demo` sandbox, so it never adds plugins to yours.
if not vim.startswith(vim.fn.stdpath('data'), root .. '/.demo/') then
	error('demo/init.lua runs only from `make demo`')
end
vim.opt.runtimepath:prepend(root)

pcall(function()
	require('vim._core.ui2').enable({})
end)
vim.o.termguicolors = true
vim.o.number = true
vim.o.laststatus = 3
vim.o.cmdheight = 0
vim.o.winborder = 'rounded'
vim.o.shortmess = vim.o.shortmess .. 'I'
vim.o.swapfile = false
vim.g.mapleader = ' '

-- `confirm = false` lets `make demo` install headless.
vim.pack.add({
	'https://github.com/rafi/morrow.nvim',
	'https://github.com/folke/snacks.nvim',
	'https://github.com/rafi/packcount.nvim',
	'https://github.com/folke/flash.nvim',
	'https://github.com/lewis6991/gitsigns.nvim',
	'https://github.com/folke/which-key.nvim',
	'https://github.com/neovim/nvim-lspconfig',
	{
		src = 'https://github.com/stevearc/conform.nvim',
		version = vim.version.range('*'),
	},
}, { confirm = false })
vim.cmd.colorscheme('morrow')

-- Added on the first InsertEnter, so the picker lists them as not loaded.
vim.api.nvim_create_autocmd('InsertEnter', {
	once = true,
	callback = function()
		vim.pack.add({
			'https://github.com/stevearc/oil.nvim',
			'https://github.com/folke/trouble.nvim',
		}, { confirm = false })
	end,
})

vim.o.statusline = " %f %m%=%{v:lua.require'packcount'.updates()} "
vim.api.nvim_create_autocmd('User', {
	pattern = 'PackcountChanged',
	command = 'redrawstatus',
})

vim.keymap.set('n', '<leader>l', '<Plug>(Packman)')
