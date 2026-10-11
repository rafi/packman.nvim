-- packman: state of one open picker (its plugin list, whether a vim.pack
-- call runs, which rows are busy) and the blocking vim.pack operations its
-- actions run.
-- https://github.com/rafi/packman.nvim

local Pack = require('packman.pack')

---@class packman.Session
---@field plugins vim.pack.PlugData[] Listed plugins, refreshed after every operation.
---@field busy boolean A vim.pack call is running.
---@field checked table<string, true> Plugins whose remote was fetched; updating only these skips downloading.
---@field working table<string, string> Rows being changed, mapped to their status label.
local Session = {}
Session.__index = Session

-- A session listing every plugin from the lockfile (no git calls), so the
-- picker opens at once; `load()` adds the last fetch's revisions after.
---@return packman.Session
function Session.new()
	return setmetatable({
		plugins = vim.pack.get(nil, { info = false }),
		busy = false,
		checked = {},
		working = {},
	}, Session)
end

-- Number of plugins with a pending update.
---@return integer
function Session:update_count()
	local count = 0
	for _, plugin in ipairs(self.plugins) do
		count = count + (Pack.has_update(plugin) and 1 or 0)
	end
	return count
end

-- Names of all listed plugins.
---@return string[]
function Session:names()
	return vim.tbl_map(function(plugin)
		return plugin.spec.name
	end, self.plugins)
end

-- Picker title with the update count (0.13+) and the running operation.
---@param picker snacks.Picker
---@param status? string
function Session:set_title(picker, status)
	local title = 'Plugins'
	if Pack.can_check then
		title = ('Plugins (%d updates)'):format(self:update_count())
	end
	picker.title = title .. (status and ' ' .. status .. '…' or '')
	picker:update_titles()
end

-- Redraws the list every 80ms to animate row spinners. Ticks during
-- vim.pack calls because their vim.wait() runs scheduled callbacks.
---@param picker snacks.Picker
---@return fun() stop
local function animate(picker)
	local timer = assert(vim.uv.new_timer())
	local function stop()
		if not timer:is_closing() then
			timer:stop()
			timer:close()
		end
	end
	timer:start(
		80,
		80,
		vim.schedule_wrap(function()
			if picker.closed then
				return stop()
			end
			picker.list:update({ force = true })
			vim.cmd.redraw()
		end)
	)
	return stop
end

-- Runs a blocking vim.pack call with `status` in the title and on `rows`,
-- then refreshes the list and packcount.nvim's count. One call at a time.
---@param picker snacks.Picker
---@param status string
---@param fn fun()
---@param rows? string[]
function Session:run(picker, status, fn, rows)
	if self.busy then
		vim.notify('vim.pack is busy', vim.log.levels.WARN)
		return
	end
	self.busy = true
	self:set_title(picker, status)
	local stop ---@type fun()?
	if rows then
		for _, name in ipairs(rows) do
			self.working[name] = status
		end
		picker.list:update({ force = true })
		stop = animate(picker)
	end
	vim.schedule(function()
		local ok, err = pcall(fn)
		self.busy = false
		self.working = {}
		if stop then
			stop()
		end
		if not ok then
			vim.notify(tostring(err), vim.log.levels.ERROR)
		end
		-- Sync packcount.nvim's count (statusline) with the fresh
		-- revisions, when it's installed.
		local has_packcount, packcount = pcall(require, 'packcount')
		if Pack.can_check and has_packcount then
			packcount.set(self.plugins)
		end
		if not picker.closed then
			self:set_title(picker)
			picker:refresh()
		end
	end)
end

-- Replaces listed plugins with `fresh` ones, by name.
---@param fresh vim.pack.PlugData[]
function Session:merge(fresh)
	local by_name = {} ---@type table<string, vim.pack.PlugData>
	for _, plugin in ipairs(fresh) do
		by_name[plugin.spec.name] = plugin
	end
	for i, plugin in ipairs(self.plugins) do
		self.plugins[i] = by_name[plugin.spec.name] or plugin
	end
end

-- Reads the last fetch's revisions (0.13+), after the picker rendered.
---@param picker snacks.Picker
function Session:load(picker)
	if not Pack.can_check then
		return
	end
	self:run(picker, 'loading', function()
		self.plugins = Pack.read_plugins()
	end)
end

-- Fetches `names` (nil for all) and reads their pending revisions.
---@param picker snacks.Picker
---@param names? string[]
function Session:check(picker, names)
	self:run(picker, 'checking', function()
		local fresh = Pack.with_last_fetch(vim.pack.get(names, { offline = false }))
		if names then
			self:merge(fresh)
		else
			self.plugins = fresh
		end
		for _, name in ipairs(names or self:names()) do
			self.checked[name] = true
		end
	end)
end

-- Whether every plugin in `names` was fetched by a check.
---@param names string[]
---@return boolean
function Session:all_checked(names)
	for _, name in ipairs(names) do
		if not self.checked[name] then
			return false
		end
	end
	return true
end

-- Updates (`target = 'version'`) or restores (`'lockfile'`) `names`, nil
-- for all, then reloads revisions. Skips downloading when every target was
-- checked in this session.
---@param picker snacks.Picker
---@param names? string[]
---@param target 'version'|'lockfile'
function Session:update(picker, names, target)
	local status = target == 'lockfile' and 'restoring' or 'updating'
	local rows = names or self:names()
	self:run(picker, status, function()
		vim.pack.update(names, {
			force = true,
			target = target,
			offline = target == 'lockfile' or self:all_checked(rows),
		})
		self.plugins = Pack.read_plugins()
	end, rows)
end

-- Deletes `names` from disk after a confirmation: vim.pack.del() refuses
-- only active plugins, so not-yet-loaded lazy plugins would go silently.
---@param picker snacks.Picker
---@param names string[]
function Session:delete(picker, names)
	local msg = 'Delete ' .. table.concat(names, ', ') .. ' from disk?'
	if vim.fn.confirm(msg, '&Yes\n&No', 2) ~= 1 then
		return
	end
	self:run(picker, 'deleting', function()
		vim.pack.del(names)
		self.plugins = Pack.read_plugins()
	end)
end

return Session
