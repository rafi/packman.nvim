-- packman: vim.pack data helpers shared by the picker, preview and diff.
-- https://github.com/rafi/packman.nvim

local M = {}

-- Whether vim.pack can check for updates (Neovim 0.13+). On 0.12 checking
-- and diffing are hidden.
M.can_check = vim.fn.has('nvim-0.13') == 1

-- Reads all plugins. On 0.13 also resolves `rev_to` from the last fetch
-- (no download); on 0.12 reads only the lockfile.
---@return vim.pack.PlugData[]
function M.read_plugins()
	if M.can_check then
		return vim.pack.get(nil, { offline = true })
	end
	return vim.pack.get(nil, { info = false })
end

-- Whether `plugin` has a fetched revision it isn't at yet.
---@param plugin vim.pack.PlugData
---@return boolean
function M.has_update(plugin)
	return plugin.rev_to ~= nil and plugin.rev ~= plugin.rev_to
end

-- Browser URL of a plugin's `spec.src`. Rewrites git's ssh forms
-- (`git@host:path`, `ssh://user@host:port/path`) and `git://` to https,
-- drops `.git`. Returns nil and a message for sources with no URL scheme,
-- like `gh:user/repo` shorthands or local paths.
---@param src string
---@return string? url
---@return string? err
function M.browse_url(src)
	local url = src:gsub('%.git/?$', '')
	local rest = url:match('^ssh://(.*)$') or url:match('^git://(.*)$')
	if rest then
		rest = rest:gsub('^[^@/]*@', ''):gsub('^([^/:]+):%d*/', '%1/')
		url = 'https://' .. rest
	end
	local host, path = url:match('^[%w._-]+@([^:/]+):/?(.+)$')
	if host then
		url = ('https://%s/%s'):format(host, path)
	end
	if not url:find('://', 1, true) then
		return nil, 'cannot open ' .. src .. ' in a browser'
	end
	return url
end

-- Re-reads offline the plugins whose online fetch failed (`rev_to` unset),
-- so they keep the last fetch's result.
---@param plugins vim.pack.PlugData[]
---@return vim.pack.PlugData[]
function M.with_last_fetch(plugins)
	local missing = {} ---@type string[]
	for _, plugin in ipairs(plugins) do
		if plugin.rev_to == nil then
			missing[#missing + 1] = plugin.spec.name
		end
	end
	if #missing == 0 then
		return plugins
	end
	local by_name = {} ---@type table<string, vim.pack.PlugData>
	for _, plugin in ipairs(vim.pack.get(missing, { offline = true })) do
		by_name[plugin.spec.name] = plugin
	end
	return vim.tbl_map(function(plugin)
		return by_name[plugin.spec.name] or plugin
	end, plugins)
end

return M
