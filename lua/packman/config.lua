-- packman configuration: defaults merged with `vim.g.packman`.
-- https://github.com/rafi/packman.nvim

---@class packman.Config
---@field picker snacks.picker.Config Deep-merged over the picker spec: layout, keys (`win.list.keys`), title, ...

---User options; every field is optional.
---@class (partial) packman.Opts: packman.Config

---@type packman.Opts?
vim.g.packman = vim.g.packman

local M = {}

---@type packman.Config
M.defaults = {
	picker = {},
}

-- Message of the last invalid `vim.g.packman`, for :checkhealth.
---@type string?
M.error = nil

local resolved ---@type packman.Config?

-- Checks the types of a merged config. Returns false and a message that
-- names the field, e.g. `vim.g.packman.picker: expected table, got number`.
---@param cfg table
---@return boolean ok
---@return string? err
function M.validate(cfg)
	local ok, err = pcall(function()
		vim.validate('picker', cfg.picker, 'table')
	end)
	if ok then
		return true
	end
	-- Drop the "file:line: " prefix error() may add.
	local msg = tostring(err):gsub('^[^\n]-:%d+: ', '')
	return false, 'vim.g.packman.' .. msg
end

-- Keys of `vim.g.packman` that packman doesn't know (typos).
---@return string[]
function M.unknown()
	local user = vim.g.packman
	if type(user) ~= 'table' then
		return {}
	end
	local ret = {} ---@type string[]
	for key in pairs(user) do
		if M.defaults[key] == nil then
			ret[#ret + 1] = tostring(key)
		end
	end
	table.sort(ret)
	return ret
end

-- Merges `vim.g.packman` over the defaults. An invalid value is reported
-- once and replaced by the defaults, so the picker still opens.
---@return packman.Config
local function resolve()
	local user = vim.g.packman
	local cfg = vim.deepcopy(M.defaults)
	local ok, err = true, nil ---@type boolean, string?
	if type(user) == 'table' then
		cfg = vim.tbl_deep_extend('force', cfg, user)
		ok, err = M.validate(cfg)
	elseif user ~= nil then
		ok, err = false, 'vim.g.packman: expected table, got ' .. type(user)
	end
	M.error = err
	if not ok then
		vim.notify(
			('packman: %s; using defaults'):format(err),
			vim.log.levels.ERROR
		)
		return vim.deepcopy(M.defaults)
	end
	return cfg
end

-- The resolved config. Read on first use, so `vim.g.packman` can be set
-- anywhere in the user's config, even after plugins are sourced.
---@return packman.Config
function M.get()
	resolved = resolved or resolve()
	return resolved
end

return M
