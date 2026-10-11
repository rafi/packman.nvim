-- packman.nvim entry point: defines :Packman and its <Plug> maps. The
-- picker loads on first use.
-- https://github.com/rafi/packman.nvim

-- vim.pack is new in Neovim 0.12. :checkhealth packman reports it.
if vim.g.loaded_packman or vim.fn.has('nvim-0.12') == 0 then
	return
end
vim.g.loaded_packman = true

-- Default highlight groups, re-applied on ColorScheme since `:colorscheme`
-- clears groups that aren't builtin.
local function set_highlights()
	vim.api.nvim_set_hl(0, 'PackmanUpdate', { default = true, link = 'Type' })
	vim.api.nvim_set_hl(
		0,
		'PackmanBusy',
		{ default = true, link = 'DiagnosticInfo' }
	)
end
set_highlights()
vim.api.nvim_create_autocmd('ColorScheme', {
	group = vim.api.nvim_create_augroup('packman', {}),
	callback = set_highlights,
})

---@type table<string, fun()>
local subcommands = {
	open = function()
		require('packman').open()
	end,
	check = function()
		require('packman').open({ check = true })
	end,
	log = function()
		require('packman').log()
	end,
}

vim.api.nvim_create_user_command('Packman', function(opts)
	local name = opts.fargs[1] or 'open'
	local sub = subcommands[name]
	if not sub then
		vim.notify('packman: unknown subcommand ' .. name, vim.log.levels.ERROR)
		return
	end
	sub()
end, {
	nargs = '?',
	desc = 'vim.pack plugins: open (picker), check (picker, fetch first), log',
	complete = function(lead, line)
		-- Only the first argument has completions.
		if line:match('^%S+%s+%S+%s') then
			return {}
		end
		local names = vim.tbl_keys(subcommands)
		table.sort(names)
		return vim.tbl_filter(function(name)
			return vim.startswith(name, lead)
		end, names)
	end,
})

vim.keymap.set('n', '<Plug>(Packman)', subcommands.open, {
	desc = 'Open the vim.pack plugin picker',
})
vim.keymap.set('n', '<Plug>(PackmanCheck)', subcommands.check, {
	desc = 'Open the vim.pack plugin picker and check for updates',
})
vim.keymap.set('n', '<Plug>(PackmanLog)', subcommands.log, {
	desc = 'Open the vim.pack update log',
})
