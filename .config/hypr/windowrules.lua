--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- and https://wiki.hypr.land/Configuring/Basics/Workspace-Rules/

local suppressMaximizeRule = hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})
-- suppressMaximizeRule:set_enabled(false)

hl.window_rule({
    -- Steam games (windowed or fullscreen) should always be fully opaque
    name  = "opaque-steam-games",
    match = { class = "^steam_app_.*$" },

    opacity = "1.0 override 1.0 override",
})

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- Layer rules also return a handle.
-- local overlayLayerRule = hl.layer_rule({
--     name  = "no-anim-overlay",
--     match = { namespace = "^my-overlay$" },
--     no_anim = true,
-- })
-- overlayLayerRule:set_enabled(false)

-- Hyprland-run windowrule
hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

-- Circular volume OSD (see ~/.config/hypr/scripts/volume-osd.py):
-- float + pin it centered near the bottom of the screen, stripped of
-- decorations/animations since it draws its own themed circle.
hl.window_rule({
    name        = "volume-osd",
    match       = { class = "^volume-osd$" },

    float       = true,
    pin         = true,
    size        = { 150, 150 },
    move        = { "(monitor_w - window_w) * 0.5", "monitor_h - window_h - 120" },
    no_anim     = true,
    no_shadow   = true,
    no_blur     = true,
    no_focus    = true,
    no_initial_focus = true,
    decorate    = false,
    rounding    = 0,
})
