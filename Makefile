.PHONY: test lint demo
# Run tests/*_spec.lua, or one file with SPEC=tests/x_spec.lua.
test:
	nvim -l tests/minit.lua $(SPEC)

lint:
	stylua --check .

# Record the README demo in a .demo/ sandbox (needs network), with plain
# less for diffs, into $(ASSETS). 128 colors keep morrow's cyan and green.
DEMO := $(CURDIR)/.demo
ASSETS ?= $(HOME)/code/rafi/assets/repo/packman.nvim
GIF_FILTER := split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=none:diff_mode=rectangle
demo: export XDG_CONFIG_HOME = $(DEMO)/config
demo: export XDG_DATA_HOME = $(DEMO)/data
demo: export XDG_STATE_HOME = $(DEMO)/state
demo: export XDG_CACHE_HOME = $(DEMO)/cache
demo: export GIT_CONFIG_GLOBAL = /dev/null
demo: export GIT_PAGER = less
demo: export LESS = -R
demo:
	rm -rf $(DEMO)
	nvim --headless -u demo/init.lua +'doautocmd InsertEnter' \
		+'luafile demo/setup.lua' +qa
	nvim --headless -u demo/init.lua +'packupdate! ++offline ++lockfile' +qa
	vhs demo/packman.tape
	mkdir -p "$(ASSETS)"
	ffmpeg -v error -y -i $(DEMO)/packman.gif -vf '$(GIF_FILTER)' \
		"$(ASSETS)/demo.gif"
	pngquant --quality=70-90 --speed 1 --force \
		--output "$(ASSETS)/picker.png" $(DEMO)/picker.png
	pngquant --quality=70-90 --speed 1 --force \
		--output "$(ASSETS)/diff.png" $(DEMO)/diff.png
