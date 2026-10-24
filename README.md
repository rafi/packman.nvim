# packman.nvim

A modern UI for Neovim's built-in plugin manager,
[`vim.pack`](https://neovim.io/doc/user/pack.html#vim.pack), modeled on
lazy.nvim's and built on the
[snacks.nvim](https://github.com/folke/snacks.nvim) picker. It is not
another plugin manager: every row comes from `vim.pack.get()` and every
action is a `vim.pack` call, so your lockfile, vim.pack's update log and
`:packupdate` stay the one source of truth.

![packman.nvim demo](https://raw.githubusercontent.com/rafi/assets/main/repo/packman.nvim/demo.gif)

- Lists every plugin: loaded or not, pending updates first. Plugins updated
  or restored in the picker come next, labeled with their new revision.
- Preview: description, source, path, version, revision, pending update
  with its commits, the commits the last update brought in, branches,
  tags, required Neovim, `spec.data`.
- Check, update, restore to the lockfile, delete, diff, update log.
- Keeps [packcount.nvim](https://github.com/rafi/packcount.nvim)'s count in
  sync when it's installed.

## Light-weight

- About 1,200 lines of Lua. Its `plugin/` file only defines `:Packman`,
  three `<Plug>` maps and two highlight groups. Nothing else loads until
  you open the picker.
- No state of its own: no cache, no database, no second lockfile. Each
  time the picker opens, it reads your plugins fresh from `vim.pack`.
- The picker is a view over what Neovim already ships:

| In the picker | What runs | Built-in equivalent |
|---|---|---|
| List, preview | `vim.pack.get()`, `git log` | `:lua =vim.pack.get()` |
| `C` check | `vim.pack.get(nil, { offline = false })` | Same call |
| `U` update | `vim.pack.update(nil, { force = true })` | `:packupdate!` |
| `R` restore | `vim.pack.update(nil, { force = true, target = 'lockfile' })` | `:packupdate! ++offline ++lockfile` |
| `x` delete | `vim.pack.del()` | `:packdel` |
| `L` log | Opens `stdpath('log')/nvim-pack.log` | Same file |

So you can mix them: an update from the picker lands in the same lockfile
and log as `:packupdate`, and after `:packupdate`, `d` in the picker still
diffs what it changed.

Requires Neovim 0.12+, snacks.nvim and git. Checking for updates needs
Neovim 0.13+.

## Install

```lua
vim.pack.add({
	'https://github.com/folke/snacks.nvim',
	'https://github.com/rafi/packman.nvim',
})
vim.keymap.set('n', '<leader>l', '<Plug>(Packman)')
```

No `setup()` call is needed, and no keymap is set for you.

## Usage

`:Packman` (or `:Packman open`) opens the picker. `:Packman check` opens it
and checks every plugin for updates right away (`C`), so `U` can apply
them. `:Packman log` opens the `vim.pack` update log. `<Plug>(Packman)`,
`<Plug>(PackmanCheck)` and `<Plug>(PackmanLog)` do the same.

![The picker, with a pending update and its commits](https://raw.githubusercontent.com/rafi/assets/main/repo/packman.nvim/picker.png)

In the picker, uppercase acts on all plugins, lowercase on the selection
(`<Tab>`) or the plugin under the cursor:

| Key | Action |
|---|---|
| `C` / `c` | Check for updates (fetch) |
| `U` / `u` | Update |
| `R` / `r` | Restore to the lockfile revision |
| `x` | Delete from disk (asks first) |
| `d`, `<CR>` | Diff the pending update in a terminal, else the last update (`git diff @{1} HEAD`) |
| `L` | Update log |
| `gx` | Open the repository (ssh sources open as https) |

After `C`, or `c` on the same plugins, `U`/`u` reuse the fetched revisions
without downloading. `vim.pack` calls block the editor while they run.

![The diff of a pending update, in git's pager](https://raw.githubusercontent.com/rafi/assets/main/repo/packman.nvim/diff.png)

## Configuration

`vim.g.packman.picker` is deep-merged over the
[snacks picker](https://github.com/folke/snacks.nvim/blob/main/docs/picker.md)
spec, so it can change the layout, title or keys. The preview footer shows
the keys that end up bound. Set it anywhere in your config, it is read when
the picker first opens.

```lua
vim.g.packman = {
	picker = {
		win = { list = { keys = { x = false, D = 'pack_delete' } } },
	},
}
```

Actions: `pack_check_all`, `pack_check`, `pack_update_all`, `pack_update`,
`pack_restore_all`, `pack_restore`, `pack_delete`, `pack_diff`, `pack_log`,
`pack_browse`. An invalid `vim.g.packman` is reported and the defaults are
used.

## Highlights

| Group | Default |
|---|---|
| `PackmanUpdate` | links to `Type`: pending update bullet and revision |
| `PackmanBusy` | links to `DiagnosticInfo`: spinner while updating |

Both are re-applied with `default = true` on `ColorScheme`, so a
colorscheme or your config can override them.

See `:h packman` and `:checkhealth packman`.

## Development

```sh
make test   # nvim -l tests/minit.lua, sandboxed under .tests/
make lint   # stylua --check
make demo   # re-record with vhs, sandboxed under .demo/, into $ASSETS
```
