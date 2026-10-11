-- :checkhealth packman
-- https://github.com/rafi/packman.nvim

local M = {}

function M.check()
	local health = vim.health

	health.start('Requirements')
	if pcall(require, 'snacks') then
		health.ok('snacks.nvim is installed')
	else
		health.error(
			'snacks.nvim not found',
			'Install https://github.com/folke/snacks.nvim'
		)
	end
	if vim.fn.has('nvim-0.12') == 0 then
		health.error('Neovim 0.12+ required: vim.pack is missing')
	elseif vim.fn.has('nvim-0.13') == 1 then
		health.ok('Neovim 0.13+: checking and diffing updates are available')
	else
		health.warn(
			'Neovim 0.12: vim.pack cannot check for updates',
			'Update, restore, delete and log still work'
		)
	end
	if vim.fn.executable('git') == 1 then
		health.ok('git is installed')
	else
		health.error('git not found in $PATH')
	end

	health.start('Configuration')
	local Config = require('packman.config')
	Config.get()
	if Config.error then
		health.error(Config.error, 'Fix vim.g.packman; defaults are in use')
	else
		health.ok('vim.g.packman is valid')
	end
	for _, key in ipairs(Config.unknown()) do
		health.warn(('Unknown option vim.g.packman.%s'):format(key))
	end

	health.start('Integrations')
	if pcall(require, 'packcount') then
		health.ok('packcount.nvim: picker actions update its count')
	else
		health.info('packcount.nvim not installed (optional statusline count)')
	end
end

return M
