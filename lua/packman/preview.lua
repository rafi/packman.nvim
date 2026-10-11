-- packman: the picker's preview, a plugin's vim.pack data as labeled,
-- colored rows followed by its pending commits.
-- https://github.com/rafi/packman.nvim

local Pack = require('packman.pack')

local M = {}

-- Width of the label column in the preview.
local label_width = 10

-- Highlight per Lua type, for `spec.data` values.
local type_hl = { string = 'String', number = 'Number', boolean = 'Boolean' }

-- Preview row: a padded label, then the highlighted value chunks.
---@param label string
---@param value snacks.picker.Highlight[]
---@return snacks.picker.Highlight[]
local function row(label, value)
	local a = Snacks.picker.util.align
	local ret = { { ' ' .. a(label, label_width), 'SnacksPickerLabel' } }
	Snacks.picker.highlight.extend(ret, value)
	return ret
end

-- `value` on one line, colored by its Lua type.
---@param value any
---@return snacks.picker.Highlight
local function inline(value)
	local text = vim.inspect(value, { newline = ' ', indent = '' })
	return { text, type_hl[type(value)] or 'Special' }
end

-- Rows for `spec.data`: one per key for tables, else a single value.
---@param data any
---@return snacks.picker.Highlight[][]
local function data_rows(data)
	if type(data) ~= 'table' or vim.tbl_isempty(data) then
		return { row('Data', { inline(data) }) }
	end
	local keys = vim.tbl_keys(data)
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	local ret = {} ---@type snacks.picker.Highlight[][]
	for i, key in ipairs(keys) do
		ret[#ret + 1] = row(i == 1 and 'Data' or '', {
			{ tostring(key), 'Identifier' },
			{ ' = ', 'SnacksPickerDelim' },
			inline(data[key]),
		})
	end
	return ret
end

-- First entry of `list` with a dimmed note and the count of the rest,
-- e.g. branches (first is the default) or tags (sorted newest first).
---@param list string[]
---@param hl string
---@param note string
---@return snacks.picker.Highlight[]
local function first_of(list, hl, note)
	local text = ' (' .. note
	if #list > 1 then
		text = text .. (', +%d more'):format(#list - 1)
	end
	return { { list[1], hl }, { text .. ')', 'SnacksPickerComment' } }
end

-- Rows of `git log` output, or its error.
---@param out vim.SystemCompleted
---@param picker snacks.Picker
---@return snacks.picker.Highlight[][]
local function parse_commits(out, picker)
	if out.code ~= 0 then
		return { { { ' ' .. vim.trim(out.stderr or ''), 'DiagnosticError' } } }
	end
	local ret = {} ---@type snacks.picker.Highlight[][]
	local lines = vim.split(out.stdout or '', '\n', { trimempty = true })
	for _, line in ipairs(lines) do
		local hash, date, author, msg = line:match('^(%S+) (%S+) (.-)\t(.*)$')
		local hl = { { ' ' } } ---@type snacks.picker.Highlight[]
		if hash then
			hl[#hl + 1] = { picker.opts.icons.git.commit, 'SnacksPickerGitCommit' }
			hl[#hl + 1] = { hash, 'SnacksPickerGitCommit' }
			hl[#hl + 1] = { ' ' .. date .. ' ', 'SnacksPickerGitDate' }
			local message = Snacks.picker.format.commit_message({ msg = msg }, picker)
			Snacks.picker.highlight.extend(hl, message)
			hl[#hl + 1] = { ' <' .. author .. '>', 'SnacksPickerGitAuthor' }
		else
			hl[#hl + 1] = { line }
		end
		ret[#ret + 1] = hl
	end
	return ret
end

-- Pending commits (`git log rev..rev_to`), one line each, colored like
-- snacks' git log: hash, date, conventional-commit message, author.
-- git runs in the background, `cb` gets the rows on the main loop.
---@param plugin vim.pack.PlugData
---@param picker snacks.Picker
---@param cb fun(commits: snacks.picker.Highlight[][])
function M.commits(plugin, picker, cb)
	local cmd = {
		'git',
		'log',
		'--no-show-signature',
		'--abbrev=7',
		'--pretty=format:%h %cs %an%x09%s',
		plugin.rev .. '..' .. plugin.rev_to,
	}
	local ok, err = pcall(
		vim.system,
		cmd,
		{ cwd = plugin.path, text = true },
		vim.schedule_wrap(function(out)
			cb(parse_commits(out, picker))
		end)
	)
	-- Spawning fails at once when git or the plugin dir is missing.
	if not ok then
		vim.schedule(function()
			cb({ { { ' ' .. tostring(err), 'DiagnosticError' } } })
		end)
	end
end

-- Preview lines: the plugin's vim.pack data as labeled, colored rows, then
-- its pending commits from `M.commits()`, nil while git runs.
---@param plugin vim.pack.PlugData
---@param commits? snacks.picker.Highlight[][]
---@return snacks.picker.Highlight[][]
function M.lines(plugin, commits)
	local spec = plugin.spec
	local manifest = plugin.manifest or {}
	local lines = {} ---@type snacks.picker.Highlight[][]

	if manifest.description then
		lines[#lines + 1] = row('About', { { manifest.description } })
	end
	lines[#lines + 1] = row(
		'Status',
		plugin.active and { { '● ', 'DiagnosticOk' }, { 'loaded' } }
			or { { '○ not loaded', 'SnacksPickerComment' } }
	)
	lines[#lines + 1] = row('Source', { { spec.src, 'Underlined' } })
	lines[#lines + 1] =
		row('Path', { { vim.fn.fnamemodify(plugin.path, ':~'), 'Directory' } })

	local version = spec.version
	if version == nil then
		lines[#lines + 1] =
			row('Version', { { 'default branch', 'SnacksPickerComment' } })
	elseif type(version) == 'string' then
		lines[#lines + 1] = row('Version', { { version, 'SnacksPickerGitBranch' } })
	else
		-- vim.VersionRange, e.g. `>=1.0.0`.
		lines[#lines + 1] = row('Version', { { tostring(version), 'Number' } })
	end

	lines[#lines + 1] =
		row('Revision', { { plugin.rev:sub(1, 7), 'SnacksPickerGitCommit' } })
	if Pack.can_check then
		local update ---@type snacks.picker.Highlight[]
		if plugin.rev_to == nil then
			update = { { 'not checked', 'SnacksPickerComment' } }
		elseif not Pack.has_update(plugin) then
			update = { { 'up to date', 'DiagnosticOk' } }
		else
			update = {
				{ plugin.rev:sub(1, 7), 'SnacksPickerGitCommit' },
				{ ' → ', 'SnacksPickerDelim' },
				{ plugin.rev_to:sub(1, 7), 'PackmanUpdate' },
			}
			if commits then
				update[#update + 1] =
					{ (' (%d commits)'):format(#commits), 'SnacksPickerComment' }
			end
		end
		lines[#lines + 1] = row('Update', update)
	end

	if plugin.branches and #plugin.branches > 0 then
		lines[#lines + 1] = row(
			'Branches',
			first_of(plugin.branches, 'SnacksPickerGitBranch', 'default')
		)
	end
	if plugin.tags and #plugin.tags > 0 then
		lines[#lines + 1] = row('Tags', first_of(plugin.tags, 'Number', 'latest'))
	end
	if manifest.engines and manifest.engines.nvim then
		lines[#lines + 1] =
			row('Requires', { { 'nvim ' .. manifest.engines.nvim, 'Number' } })
	end
	if manifest.scripts and not vim.tbl_isempty(manifest.scripts) then
		local names = vim.tbl_keys(manifest.scripts)
		table.sort(names)
		lines[#lines + 1] =
			row('Scripts', { { table.concat(names, ', '), 'Special' } })
	end
	if spec.data ~= nil then
		vim.list_extend(lines, data_rows(spec.data))
	end

	if commits and #commits > 0 then
		lines[#lines + 1] = {}
		lines[#lines + 1] = { { ' Pending commits', 'Title' } }
		vim.list_extend(lines, commits)
	end
	return lines
end

return M
