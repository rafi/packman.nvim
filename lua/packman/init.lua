-- packman.nvim: vim.pack plugin manager picker, modeled on lazy.nvim's UI
-- (requires snacks.nvim). Public API; the modules it uses:
--   config   defaults merged with vim.g.packman
--   picker   snacks picker spec: layout, rows, keys, actions
--   session  one picker's plugin list and its blocking vim.pack calls
--   preview  the preview pane's rows and pending commits
--   float    diff terminal and update log windows
--   pack     vim.pack helpers (reading plugins, pending updates)
-- https://github.com/rafi/packman.nvim

---@class packman
local M = {}

-- Whether snacks.nvim is installed. Loads it, which defines the `Snacks`
-- global the picker uses; notifies when it's missing.
---@return boolean
local function has_snacks()
	if pcall(require, 'snacks') then
		return true
	end
	vim.notify('packman: snacks.nvim is required', vim.log.levels.ERROR)
	return false
end

---@class packman.OpenOpts
---@field check? boolean Fetch every plugin's remote right away (Neovim 0.13+), as `C` does.

-- Opens the picker of all vim.pack plugins.
---@param opts? packman.OpenOpts
function M.open(opts)
	if has_snacks() then
		require('packman.picker').open(opts)
	end
end

-- Opens vim.pack's update log (`stdpath('log')/nvim-pack.log`) in a float.
function M.log()
	if has_snacks() then
		require('packman.float').log()
	end
end

return M
