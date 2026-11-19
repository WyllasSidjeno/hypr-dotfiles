-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
-- HYPRLAND CONFIG ENTRYPOINT.                            --
-- Split into sibling files below; edit those, not this.  --
-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
-- https://wiki.hypr.land/Configuring/Start/

-- programs.lua must load first: it sets globals (terminal, fileManager,
-- menu, bar, applet, mainMod) that autostart.lua and keybinds.lua use.
require("programs")

require("monitors")
require("autostart")
require("env")
require("permissions")
require("appearance")
require("input")
require("keybinds")
require("windowrules")
