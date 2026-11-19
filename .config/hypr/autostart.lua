-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

hl.on("hyprland.start", function ()
   hl.exec_cmd(terminal)
   hl.exec_cmd(applet)
   hl.exec_cmd(bar)
   hl.exec_cmd("dunst")
 end)
