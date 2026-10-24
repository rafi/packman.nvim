-- packman: the snacks.nvim picker spec (layout, rows, keys, actions) for
-- one session, with `vim.g.packman.picker` merged over it.
-- https://github.com/rafi/packman.nvim

local Config = require('packman.config')
local Float = require('packman.float')
local Pack = require('packman.pack')
local Preview = require('packman.preview')
local Session = require('packman.session')

local M = {}

-- Preview footer key hints: the actions each one covers, and its label.
local hints = {
	{ { 'pack_check_all', 'pack_check' }, 'check' },
	{ { 'pack_update_all', 'pack_update' }, 'update' },
	{ { 'pack_restore_all', 'pack_restore' }, 'restore' },
	{ { 'pack_diff' }, 'diff' },
	{ { 'pack_delete' }, 'delete' },
	{ { 'pack_log' }, 'log' },
}

-- Action a snacks key spec runs: `'action'` or `{ 'action', desc = ... }`.
---@param spec any
---@return string?
local function key_action(spec)
	if type(spec) == 'table' then
		spec = spec[1]
	end
	return type(spec) == 'string' and spec or nil
end

-- Preview footer from `hints`, showing the keys bound in `list_keys`.
-- Hints with no bound key are left out.
---@param list_keys table<string, any>
---@return string[][]
local function footer(list_keys)
	local by_action = {} ---@type table<string, string[]>
	for lhs, spec in pairs(list_keys) do
		local action = key_action(spec)
		if action then
			by_action[action] = by_action[action] or {}
			table.insert(by_action[action], lhs)
		end
	end
	local ret = {} ---@type string[][]
	for _, hint in ipairs(hints) do
		local lhs = {} ---@type string[]
		for _, action in ipairs(hint[1]) do
			local bound = by_action[action] or {}
			table.sort(bound)
			vim.list_extend(lhs, bound)
		end
		if #lhs > 0 then
			ret[#ret + 1] =
				{ ' ' .. table.concat(lhs, '/') .. ' ', 'SnacksFooterKey' }
			ret[#ret + 1] = { ' ' .. hint[2] .. ' ', 'SnacksFooterDesc' }
		end
	end
	return ret
end

-- List-only, preview on the right with the key hints in its footer.
---@param list_keys table<string, any>
---@return snacks.picker.layout.Config
local function layout(list_keys)
	return {
		hidden = { 'input' },
		layout = {
			box = 'horizontal',
			width = 0.8,
			min_width = 120,
			height = 0.8,
			{
				box = 'vertical',
				border = true,
				title = '{title} {live} {flags}',
				{ win = 'input', height = 1, border = 'bottom' },
				{ win = 'list', border = 'none' },
			},
			{
				win = 'preview',
				title = '{preview}',
				border = true,
				width = 0.6,
				footer = footer(list_keys),
				footer_pos = 'center',
			},
		},
	}
end

-- List keys: uppercase acts on all plugins, lowercase on the selection or
-- the cursor. Checking needs Neovim 0.13+.
---@return table<string, table>
local function keys()
	-- stylua: ignore
	local ret = {
		['C'] = { 'pack_check_all', desc = 'Check All for Updates' },
		['c'] = { 'pack_check', desc = 'Check for Updates' },
		['U'] = { 'pack_update_all', desc = 'Update All' },
		['u'] = { 'pack_update', desc = 'Update' },
		['R'] = { 'pack_restore_all', desc = 'Restore All to Lockfile' },
		['r'] = { 'pack_restore', desc = 'Restore to Lockfile' },
		['x'] = { 'pack_delete', desc = 'Delete' },
		['d'] = { 'pack_diff', desc = 'Diff Pending or Last Update' },
		['L'] = { 'pack_log', desc = 'Update Log' },
		['gx'] = { 'pack_browse', desc = 'Open Repository' },
	}
	if not Pack.can_check then
		ret['C'], ret['c'] = nil, nil
	end
	return ret
end

-- Sort group of an item: pending update, then updated or restored in this
-- session, then the rest.
---@param item snacks.picker.finder.Item
---@return integer
local function rank(item)
	return item.update and 1 or item.change and 2 or 3
end

-- Picker items, pending updates first, then plugins this session updated
-- or restored, each group by name.
---@param session packman.Session
---@return snacks.picker.finder.Item[]
local function to_items(session)
	local items = {} ---@type snacks.picker.finder.Item[]
	for _, plugin in ipairs(session.plugins) do
		items[#items + 1] = {
			text = plugin.spec.name,
			file = plugin.path,
			dir = true,
			plugin = plugin,
			update = Pack.has_update(plugin),
			change = session.changed[plugin.spec.name],
		}
	end
	table.sort(items, function(a, b)
		if rank(a) ~= rank(b) then
			return rank(a) < rank(b)
		end
		return a.text:lower() < b.text:lower()
	end)
	return items
end

-- A list row. Bullet: spinner while busy, orange for a pending update,
-- else hollow and colored by whether the plugin is loaded. Plugins this
-- session updated or restored end with the action and new revision.
---@param item snacks.picker.Item
---@param session packman.Session
---@return snacks.picker.Highlight[]
local function format(item, session)
	local plugin = item.plugin ---@type vim.pack.PlugData
	local ret = {} ---@type snacks.picker.Highlight[]
	local status = session.working[item.text]
	if status then
		ret[#ret + 1] = { Snacks.util.spinner() .. ' ', 'PackmanBusy' }
	elseif item.update then
		ret[#ret + 1] = { '● ', 'PackmanUpdate' }
	else
		ret[#ret + 1] = { '○ ', plugin.active and 'DiagnosticOk' or 'Comment' }
	end
	local hl = plugin.active and 'SnacksPickerFile' or 'SnacksPickerComment'
	ret[#ret + 1] = { item.text, hl }
	if item.update then
		ret[#ret + 1] = {
			('  %s..%s'):format(plugin.rev:sub(1, 7), plugin.rev_to:sub(1, 7)),
			'SnacksPickerComment',
		}
	end
	local change = item.change ---@type packman.Change?
	if change and not status then
		ret[#ret + 1] = { '  ' .. change.action .. ' → ', 'SnacksPickerComment' }
		ret[#ret + 1] = { change.to:sub(1, 7), 'DiagnosticOk' }
	end
	if status then
		ret[#ret + 1] = { '  ' .. status .. '…', 'PackmanBusy' }
	end
	return ret
end

-- Renders an item's preview. Lines are built once per item, and again when
-- its commits arrive from git: pending ones (`rev..rev_to`), else the ones
-- its last update in this session brought in (`@{1}..HEAD`, HEAD's
-- previous position). Items are rebuilt on every refresh, so they never go
-- stale.
---@param ctx snacks.picker.preview.ctx
local function preview(ctx)
	local item, picker = ctx.item, ctx.picker
	local range = item.update and item.plugin.rev .. '..' .. item.plugin.rev_to
		or item.change and '@{1}..HEAD'
	if range and not item.commits and not item.loading then
		item.loading = true
		Preview.commits(item.plugin, range, picker, function(commits)
			item.commits, item.lines = commits, nil
			if not picker.closed and picker:current({ resolve = false }) == item then
				picker.preview:show(picker, { force = true })
			end
		end)
	end
	ctx.preview:reset()
	ctx.preview:minimal()
	ctx.preview:set_title(item.text)
	item.lines = item.lines
		or Preview.lines(item.plugin, item.commits, item.change)
	Snacks.picker.highlight.render(ctx.buf, ctx.preview:ns(), item.lines)
	ctx.preview:wo({ wrap = true, linebreak = true, breakindent = true })
end

-- Names of the selected plugins, or of the one under the cursor.
---@param picker snacks.Picker
---@return string[]
local function targets(picker)
	return vim.tbl_map(function(item)
		return item.text
	end, picker:selected({ fallback = true }))
end

-- Picker actions, bound to `session`.
---@param session packman.Session
---@return table<string, snacks.picker.Action.spec>
local function actions(session)
	return {
		pack_diff = function(_, item)
			if item then
				Float.diff(item.plugin)
			end
		end,
		pack_check_all = function(p)
			session:check(p)
		end,
		pack_check = function(p)
			session:check(p, targets(p))
		end,
		pack_update_all = function(p)
			session:update(p, nil, 'version')
		end,
		pack_update = function(p)
			session:update(p, targets(p), 'version')
		end,
		pack_restore_all = function(p)
			session:update(p, nil, 'lockfile')
		end,
		pack_restore = function(p)
			session:update(p, targets(p), 'lockfile')
		end,
		pack_delete = function(p)
			session:delete(p, targets(p))
		end,
		pack_log = function()
			Float.log()
		end,
		pack_browse = function(_, item)
			if not item then
				return
			end
			local url, err = Pack.browse_url(item.plugin.spec.src)
			if url then
				err = select(2, vim.ui.open(url))
			end
			if err then
				vim.notify('packman: ' .. err, vim.log.levels.ERROR)
			end
		end,
	}
end

-- Opens the picker on a new session. Fetches only on `C`/`c`, or at once
-- with `opts.check`; vim.pack calls block the UI while they run.
---@param opts? packman.OpenOpts
function M.open(opts)
	opts = opts or {}
	local check = opts.check and Pack.can_check
	if opts.check and not Pack.can_check then
		vim.notify(
			'packman: checking for updates needs Neovim 0.13+',
			vim.log.levels.WARN
		)
	end
	local user = Config.get().picker
	-- vim.pack.get() throws when git is missing or the lockfile is broken.
	local ok, session = pcall(Session.new)
	if not ok then
		vim.notify('packman: ' .. tostring(session), vim.log.levels.ERROR)
		return
	end
	-- The footer shows the keys the user's overrides leave bound.
	local user_keys = vim.tbl_get(user, 'win', 'list', 'keys')
	local list_keys = vim.tbl_extend(
		'force',
		keys(),
		type(user_keys) == 'table' and user_keys or {}
	)
	local spec = vim.tbl_deep_extend('force', {
		title = 'Plugins',
		focus = 'list',
		layout = layout(list_keys),
		finder = function()
			return to_items(session)
		end,
		format = function(item)
			return format(item, session)
		end,
		preview = preview,
		confirm = 'pack_diff',
		actions = actions(session),
		win = { list = { keys = keys() } },
	}, user)
	local picker = Snacks.picker.pick(spec)
	-- One vim.pack call runs at a time, so the check replaces the initial
	-- load (it reads the same revisions, plus the fetched ones).
	if check then
		session:check(picker)
	else
		session:load(picker)
	end
end

return M
