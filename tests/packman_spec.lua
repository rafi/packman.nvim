-- packman: the plugin/ entry point and the picker against the sandbox's
-- vim.pack plugins (mini.test, snacks.nvim).

local H = { eq = MiniTest.expect.equality, expect = MiniTest.expect }

-- Plugin root, from this file's path.
local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')

local child = MiniTest.new_child_neovim()

-- Starts a child with this plugin on 'runtimepath' and the sandbox's
-- plugins on 'packpath' (mini.test's child always runs `--clean`, which
-- drops the data dir). `snacks` adds snacks.nvim.
---@param snacks? boolean
local function start_child(snacks)
	local site = vim.fn.stdpath('data') .. '/site'
	child.start({
		'--cmd',
		'set rtp^=' .. vim.fn.fnameescape(root),
		'--cmd',
		'set packpath^=' .. vim.fn.fnameescape(site),
	})
	child.lua([[
		_G.msgs = {}
		vim.notify = function(msg) table.insert(_G.msgs, msg) end
	]])
	if snacks then
		child.cmd('packadd snacks.nvim')
	end
end

local T = MiniTest.new_set({
	hooks = {
		post_case = function()
			child.stop()
		end,
	},
})

T['entry point'] = MiniTest.new_set()

T['entry point']['requires nothing until used'] = function()
	start_child()
	H.eq(child.lua_get([[package.loaded['packman'] == nil]]), true)
	H.eq(child.fn.exists(':Packman'), 2)
	H.eq(
		child.lua_get([[vim.fn.maparg('<Plug>(Packman)', 'n', false, true).desc]]),
		'Open the vim.pack plugin picker'
	)
	H.eq(child.fn.maparg('<Plug>(PackmanLog)', 'n') ~= '', true)
end

T['entry point']['completes subcommands'] = function()
	start_child()
	H.eq(
		child.fn.getcompletion('Packman ', 'cmdline'),
		{ 'check', 'log', 'open' }
	)
	H.eq(child.fn.getcompletion('Packman l', 'cmdline'), { 'log' })
	H.eq(child.fn.getcompletion('Packman log ', 'cmdline'), {})
end

T['entry point']['reports an unknown subcommand'] = function()
	start_child()
	child.cmd('Packman nope')
	H.eq(child.lua_get('_G.msgs'), { 'packman: unknown subcommand nope' })
end

T['entry point']['needs snacks.nvim'] = function()
	start_child()
	child.cmd('Packman')
	H.eq(child.lua_get('_G.msgs'), { 'packman: snacks.nvim is required' })
end

T['entry point']['keeps highlights across colorschemes'] = function()
	start_child()
	local link = [[vim.api.nvim_get_hl(0, { name = 'PackmanUpdate' }).link]]
	H.eq(child.lua_get(link), 'Type')
	child.cmd('colorscheme blue')
	H.eq(child.lua_get(link), 'Type')
	H.eq(
		child.lua_get([[vim.api.nvim_get_hl(0, { name = 'PackmanBusy' }).link]]),
		'DiagnosticInfo'
	)
	H.eq(child.lua_get([[package.loaded['packman'] == nil]]), true)
end

T['picker'] = MiniTest.new_set()

-- Names of the open picker's items, once it lists `want`.
---@param want string
---@return string[]
local function picker_names(want)
	return child.lua(
		[[
		local want = ...
		local names = {}
		vim.wait(5000, function()
			local picker = Snacks.picker.get()[1]
			names = picker and vim.tbl_map(function(item)
				return item.text
			end, picker:items()) or {}
			return vim.list_contains(names, want)
		end, 20)
		return names
	]],
		{ want }
	)
end

T['picker']['lists vim.pack plugins'] = function()
	start_child(true)
	child.cmd('Packman')
	local names = picker_names('snacks.nvim')
	H.eq(vim.list_contains(names, 'snacks.nvim'), true)
	H.eq(vim.list_contains(names, 'mini.test'), true)
	H.eq(child.lua_get('_G.msgs'), {})
end

-- With packcount.nvim installed, the revisions the picker reads replace its
-- count, so the statusline agrees with the picker.
T['picker']['syncs packcount.nvim'] = function()
	if vim.fn.has('nvim-0.13') == 0 then
		MiniTest.skip('vim.pack checks need Neovim 0.13')
	end
	start_child(true)
	child.lua([[
		_G.synced = nil
		package.preload['packcount'] = function()
			return {
				set = function(plugins)
					_G.synced = vim.tbl_map(function(p) return p.spec.name end, plugins)
				end,
			}
		end
	]])
	child.cmd('Packman')
	child.lua('vim.wait(5000, function() return _G.synced ~= nil end, 20)')
	local synced = child.lua_get('_G.synced')
	H.eq(vim.list_contains(synced, 'snacks.nvim'), true)
end

-- `:Packman check` fetches every plugin as soon as the picker opens, instead
-- of the offline load (one vim.pack call at a time, so both would collide).
-- Fetches are redirected offline, so the test needs no network.
T['picker']['check fetches all plugins on open'] = function()
	if vim.fn.has('nvim-0.13') == 0 then
		MiniTest.skip('vim.pack checks need Neovim 0.13')
	end
	start_child(true)
	child.lua([[
		_G.synced = nil
		_G.fetched = nil
		package.preload['packcount'] = function()
			return { set = function() _G.synced = true end }
		end
		local get = vim.pack.get
		vim.pack.get = function(names, opts)
			if opts and opts.offline == false then
				_G.fetched = names == nil and 'all' or names
				opts = vim.tbl_extend('force', opts, { offline = true })
			end
			return get(names, opts)
		end
	]])
	child.cmd('Packman check')
	child.lua('vim.wait(5000, function() return _G.synced ~= nil end, 20)')
	H.eq(child.lua_get('_G.fetched'), 'all')
	H.eq(child.lua_get('_G.msgs'), {})
	H.eq(vim.list_contains(picker_names('snacks.nvim'), 'mini.test'), true)
end

-- Waits until no vim.pack call runs (the title loses its status).
local function wait_idle()
	child.lua([[
		vim.wait(5000, function()
			local picker = Snacks.picker.get()[1]
			return picker and not picker.title:find('…', 1, true)
		end, 20)
	]])
end

T['picker']['reports vim.pack errors instead of throwing'] = function()
	start_child(true)
	child.lua([[
		vim.pack.get = function()
			error('E5808: git not found', 0)
		end
	]])
	child.cmd('Packman')
	H.eq(child.lua_get('_G.msgs'), { 'packman: E5808: git not found' })
	H.eq(child.lua_get('#Snacks.picker.get()'), 0)
end

-- `c` fetches the plugin under the cursor, so a following `u` on it skips
-- downloading, while `U` on all plugins still downloads.
T['picker']['updates checked plugins offline'] = function()
	if vim.fn.has('nvim-0.13') == 0 then
		MiniTest.skip('vim.pack checks need Neovim 0.13')
	end
	start_child(true)
	child.lua([[
		_G.updates = {}
		local get = vim.pack.get
		vim.pack.get = function(names, opts)
			if opts and opts.offline == false then
				opts = vim.tbl_extend('force', opts, { offline = true })
			end
			return get(names, opts)
		end
		vim.pack.update = function(names, opts)
			table.insert(_G.updates, { names = names or 'all', offline = opts.offline })
		end
	]])
	child.cmd('Packman')
	picker_names('snacks.nvim')
	wait_idle()
	local name = child.lua_get('Snacks.picker.get()[1]:current().text')
	for _, action in ipairs({ 'pack_check', 'pack_update', 'pack_update_all' }) do
		child.lua('Snacks.picker.get()[1]:action(...)', { action })
		wait_idle()
	end
	H.eq(child.lua_get('_G.updates'), {
		{ names = { name }, offline = true },
		{ names = 'all', offline = false },
	})
	H.eq(child.lua_get('_G.msgs'), {})
end

-- `gx` turns git's ssh sources into https URLs and reports sources it
-- can't open, like `gh:` shorthands.
T['picker']['opens repositories in a browser'] = function()
	start_child(true)
	child.lua([[
		_G.opened = {}
		local get = vim.pack.get
		vim.pack.get = function(...)
			local plugins = get(...)
			for _, plugin in ipairs(plugins) do
				plugin.spec.src = _G.src:format(plugin.spec.name)
			end
			return plugins
		end
		vim.ui.open = function(url)
			table.insert(_G.opened, url)
			return nil, _G.open_err
		end
	]])
	-- Opens a picker on plugins from `src` (`%s` is the name) and runs `gx`
	-- on the plugin under the cursor. Returns its name.
	local function browse(src)
		child.lua('_G.src = ...', { src })
		child.cmd('Packman')
		picker_names('snacks.nvim')
		wait_idle()
		return child.lua([[
			local picker = Snacks.picker.get()[1]
			picker:action('pack_browse')
			local name = picker:current().text
			picker:close()
			return name
		]])
	end
	local a = browse('git@github.com:me/%s.git')
	local b = browse('ssh://git@example.com:22/me/%s')
	H.eq(child.lua_get('_G.opened'), {
		'https://github.com/me/' .. a,
		'https://example.com/me/' .. b,
	})
	H.eq(child.lua_get('_G.msgs'), {})

	child.lua([[_G.open_err = 'no browser']])
	browse('https://example.com/me/%s.git')
	local c = browse('gh:me/%s')
	H.eq(child.lua_get('_G.msgs'), {
		'packman: no browser',
		('packman: cannot open gh:me/%s in a browser'):format(c),
	})
	H.eq(#child.lua_get('_G.opened'), 3)
end

-- The preview lists pending commits once git log finishes in the
-- background.
T['picker']['previews pending commits'] = function()
	if vim.fn.has('nvim-0.13') == 0 then
		MiniTest.skip('pending updates (rev_to) need Neovim 0.13')
	end
	start_child(true)
	local path = vim.fn.stdpath('data') .. '/site/pack/core/opt/snacks.nvim'
	local function rev(ref)
		local out = vim.system({ 'git', 'rev-parse', ref }, { cwd = path }):wait()
		return vim.trim(out.stdout)
	end
	child.lua(
		[[
		local old, new = ...
		local get = vim.pack.get
		vim.pack.get = function(...)
			local plugins = get(...)
			for _, plugin in ipairs(plugins) do
				if plugin.spec.name == 'snacks.nvim' then
					plugin.rev, plugin.rev_to = old, new
				end
			end
			return plugins
		end
	]],
		{ rev('HEAD~2'), rev('HEAD') }
	)
	child.cmd('Packman')
	local text = child.lua([[
		local text = ''
		vim.wait(5000, function()
			local picker = Snacks.picker.get()[1]
			local buf = picker and picker.preview.win.buf
			if buf then
				text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
			end
			return text:find('Pending commits', 1, true) ~= nil
		end, 20)
		return text
	]])
	H.eq(text:find('Pending commits', 1, true) ~= nil, true)
	H.eq(text:find('(2 commits)', 1, true) ~= nil, true)
	H.eq(child.lua_get('_G.msgs'), {})
end

T['config'] = MiniTest.new_set()

-- Lines of `:checkhealth packman`.
---@return string[]
local function health()
	child.cmd('checkhealth packman')
	return child.api.nvim_buf_get_lines(0, 0, -1, false)
end

---@param lines string[]
---@param text string
---@return boolean
local function has_line(lines, text)
	for _, line in ipairs(lines) do
		if line:find(text, 1, true) then
			return true
		end
	end
	return false
end

T['config']['reports a bad picker field and opens with defaults'] = function()
	start_child(true)
	child.lua([[vim.g.packman = { picker = 1, typo = true }]])
	child.cmd('Packman')
	H.eq(vim.list_contains(picker_names('snacks.nvim'), 'snacks.nvim'), true)
	H.eq(child.lua_get('_G.msgs'), {
		'packman: vim.g.packman.picker: expected table, got number; using defaults',
	})
	local lines = health()
	H.eq(
		has_line(lines, 'vim.g.packman.picker: expected table, got number'),
		true
	)
	H.eq(has_line(lines, 'Unknown option vim.g.packman.typo'), true)
end

T['config']['reports a non-table vim.g.packman'] = function()
	start_child()
	child.lua([[vim.g.packman = 'nope']])
	H.eq(has_line(health(), 'vim.g.packman: expected table, got string'), true)
	H.eq(child.lua_get('_G.msgs'), {
		'packman: vim.g.packman: expected table, got string; using defaults',
	})
end

T['config']['merges picker keys and shows them in the footer'] = function()
	start_child(true)
	child.lua([[
		vim.g.packman = {
			picker = { win = { list = { keys = { x = false, D = 'pack_delete' } } } },
		}
	]])
	child.cmd('Packman')
	picker_names('snacks.nvim')
	local got = child.lua([[
		local picker = Snacks.picker.get()[1]
		local footer = vim.api.nvim_win_get_config(picker.preview.win.win).footer
		local keys = {}
		for _, chunk in ipairs(footer) do
			if chunk[2] == 'SnacksFooterKey' then
				keys[#keys + 1] = vim.trim(chunk[1])
			end
		end
		return vim.api.nvim_buf_call(picker.list.win.buf, function()
			return {
				D = vim.fn.maparg('D', 'n', false, true).buffer == 1,
				x = vim.fn.maparg('x', 'n', false, true).buffer == 1,
				keys = keys,
			}
		end)
	]])
	H.eq(got.D, true)
	H.eq(got.x, false)
	H.eq(vim.list_contains(got.keys, 'D'), true)
	H.eq(vim.list_contains(got.keys, 'x'), false)
	H.eq(has_line(health(), 'vim.g.packman is valid'), true)
end

return T
