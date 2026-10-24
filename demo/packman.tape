# README demo GIF and stills. Run with `make demo`.

Output .demo/packman.gif
Require nvim
Require git

Set Shell "bash"
Set Width 1280
Set Height 720
Set TypingSpeed 60ms
Set Framerate 20
# vim.pack blocks while it fetches, so steps Wait instead of Sleep.
Set WaitTimeout 60s

# morrow's background, so the padding blends in.
Set Theme { "name": "morrow-night", "background": "#1d1f21", "foreground": "#c5c8c6", "selection": "#373b41", "cursor": "#c5c8c6", "black": "#282a2e", "red": "#cc6666", "green": "#b5bd68", "yellow": "#f0c674", "blue": "#81a2be", "magenta": "#b294bb", "cyan": "#8abeb7", "white": "#b4b7b4", "brightBlack": "#7e8181", "brightRed": "#cc6666", "brightGreen": "#b5bd68", "brightYellow": "#f0c674", "brightBlue": "#81a2be", "brightMagenta": "#b294bb", "brightCyan": "#8abeb7", "brightWhite": "#c5c8c6" }
Set BorderRadius 14
Set WindowBar Colorful
Set WindowBarSize 40
Set Margin 20
Set MarginFill "#674EFF"
Set Padding 16

# Mono keeps icons one cell wide, Symbols Nerd Font adds the commit icon.
Set FontFamily "PragmataPro Mono, Symbols Nerd Font Mono"
Set FontSize 19
Set LetterSpacing 1
Set LineHeight 1.1

Hide
Type@0ms "clear; nvim -u demo/init.lua"
Enter
Sleep 2s
Show

Sleep 500ms
Type ":Packman" Sleep 400ms Enter
Wait+Screen /Plugins \(3 updates\)/
Sleep 2.5s
Down
Wait+Screen /opt\/gitsigns\.nvim/
Sleep 1s
Screenshot .demo/picker.png
Sleep 1.5s

# Screenshot right after Wait: after a long Sleep VHS saves a stale frame.
Type "d"
Wait+Screen /diff --git/
Screenshot .demo/diff.png
Sleep 2s
Type "q"
Wait+Screen /Plugins \(3 updates\)/
Sleep 1s

Type "u"
Wait+Screen /Plugins \(2 updates\)/
Sleep 2.5s
Type "U"
Wait+Screen /Plugins \(0 updates\)/
Sleep 4s
