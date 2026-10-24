-- packman: floating windows opened from the picker, the diff terminal
-- and the vim.pack update log.
-- https://github.com/rafi/packman.nvim

local Pack = require('packman.pack')

local M = {}

-- git's pager, read once per Neovim session: `git var` blocks, and the
-- pager rarely differs between repos.
local git_pager ---@type string?

-- Pager env that keeps less open on short diffs: `-+F` undoes less's
-- quit-if-one-screen, which would close the float at once. Also appended to
-- git's pager when it ends in less, since e.g. `LESS= less -RF` ignores $LESS.
---@param cwd string
---@return table<string, string>
local function pager_env(cwd)
	if not git_pager then
		local out = vim
			.system({ 'git', 'var', 'GIT_PAGER' }, { cwd = cwd, text = true })
			:wait()
		git_pager = vim.trim(out.stdout or '')
	end
	local env = { LESS = (vim.env.LESS or '') .. ' -+F' }
	if git_pager:match('less[^|]*$') then
		env.GIT_PAGER = git_pager .. ' -+F'
	end
	return env
end

-- Revisions to diff: the pending update (`rev rev_to`), else the last
-- change to HEAD (`@{1} HEAD`, HEAD's previous position in the reflog).
-- Returns nil and a message when neither moved anything.
---@param plugin vim.pack.PlugData
---@return string[]? refs `git diff` arguments.
---@return string title Short revisions, or the message.
local function diff_refs(plugin)
	if Pack.has_update(plugin) then
		return { plugin.rev, plugin.rev_to },
			('%s..%s'):format(plugin.rev:sub(1, 7), plugin.rev_to:sub(1, 7))
	end
	local none = plugin.spec.name .. ' has no pending or recent updates'
	local ok, out = pcall(function()
		return vim
			.system(
				{ 'git', 'rev-parse', 'HEAD', '@{1}' },
				{ cwd = plugin.path, text = true }
			)
			:wait()
	end)
	-- No reflog entry, or the previous HEAD is the same commit (e.g. the
	-- clone's checkout).
	local revs = ok and out.code == 0 and vim.split(vim.trim(out.stdout), '\n')
	if not revs or #revs ~= 2 or revs[1] == revs[2] then
		return nil, none
	end
	return { '@{1}', 'HEAD' },
		('%s..%s'):format(revs[2]:sub(1, 7), revs[1]:sub(1, 7))
end

-- Floating terminal with `git diff` of the refs from `diff_refs()`.
-- Quitting the pager early kills git with SIGPIPE (141), so closing is
-- handled here: snacks' auto_close treats any non-zero code as an error.
---@param plugin vim.pack.PlugData
function M.diff(plugin)
	local refs, title = diff_refs(plugin)
	if not refs then
		vim.notify(title)
		return
	end
	local term = Snacks.terminal.open(vim.list_extend({ 'git', 'diff' }, refs), {
		cwd = plugin.path,
		env = pager_env(plugin.path),
		auto_close = false,
		win = {
			position = 'float',
			border = vim.o.winborder,
			width = 0.85,
			height = 0.85,
			-- Above the picker.
			zindex = Snacks.win.zindex(),
			title = (' %s %s '):format(plugin.spec.name, title),
		},
	})
	-- Close on success or SIGPIPE; otherwise keep git's output and notify.
	term:on('TermClose', function()
		local status = vim.v.event.status
		if status == 0 or status == 141 then
			term:close()
		else
			vim.notify(
				('git diff exited with code %d'):format(status),
				vim.log.levels.ERROR
			)
		end
	end, { buf = true })
end

-- Opens vim.pack's update log in a float, at the latest entry.
function M.log()
	local file = vim.fn.stdpath('log') .. '/nvim-pack.log'
	if not vim.uv.fs_stat(file) then
		vim.notify('No vim.pack log yet: ' .. file, vim.log.levels.WARN)
		return
	end
	---@diagnostic disable-next-line: missing-fields
	local win = Snacks.win({
		file = file,
		border = vim.o.winborder,
		width = 0.8,
		height = 0.8,
		zindex = Snacks.win.zindex(),
		wo = { spell = false, wrap = false },
	})
	vim.api.nvim_win_call(win.win, function()
		vim.cmd('normal! G')
	end)
end

return M
