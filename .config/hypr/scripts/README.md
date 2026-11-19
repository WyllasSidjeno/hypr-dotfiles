# wallpaper-watchdog — aquamarine#383/#386 mitigation

## Symptom
After the TV (monitor `HDMI-A-1`) has been powered off for a while and is
turned back on, the desktop shows Hyprland's built-in default wallpaper
instead of the real one (`~/Pictures/wallpapers/wallpaper.png`). Moving the
mouse looks like it "fixes" it but doesn't — the session was never actually
dead, Hyprland was just dark/asleep and the stale default background became
visible on wake.

## Root cause
Two related, **upstream, unfixed** bugs in `aquamarine` (Hyprland's DRM
backend library), reproduced and confirmed on this machine
(`hyprland 0.57.0-1`, `aquamarine 0.15.1-1`, Arch):

1. **hyprwm/aquamarine#383** — when a monitor's HDMI/DP link actually drops
   (many TVs do this on auto-standby, not just DPMS-blank) and reconnects,
   `Aquamarine::CDRMBackend`'s teardown path
   (`~CDRMBackend → SDRMConnector::disconnect() → cancelAsyncOutput() →
   flushAsyncCommitEvents()`) can dereference a null connector slot and
   SIGSEGV. When this hits, **Hyprland itself crashes** (not just hyprpaper),
   taking the whole Wayland session down — confirmed in
   `journalctl --user -u wayland-wm@hyprland.desktop.service`, crashes on
   2026-11-06, 2026-11-08, 2026-11-09, all at the moment the monitor
   reconnected, all with the identical stack trace. `hyprpaper.service`'s own
   `Restart=on-failure` can't help here since the compositor itself is dead —
   recovery requires logging back in.
2. **hyprwm/aquamarine#386-adjacent (same reconnect path)** — on a "softer"
   reconnect, Hyprland survives but `hyprpaper`'s wlr-layer-shell surface
   goes stale: `hyprctl hyprpaper listactive` keeps reporting the correct
   wallpaper path even though nothing is actually being rendered, because the
   surface is still bound to the pre-reconnect output. This is the "default
   wallpaper" symptom above. Verified on this machine on 2026-11-10: a plain
   `systemctl --user restart hyprpaper.service` with no config change fixed
   it instantly, proving the IPC "active" state was lying about the real
   render state.

Neither bug is in this machine's `hyprland.lua` / `hyprpaper.conf` — both are
fixed-but-unreleased upstream (a one-line null-check patch, `fc77bd5`, is
confirmed by multiple independent reporters on the GitHub issue but not yet
tagged into an Arch package as of `aquamarine 0.15.1-1`).

## Mitigation deployed here
`wallpaper-watchdog.sh` + `wallpaper-watchdog.service` (systemd user unit,
`~/.config/systemd/user/`): listens on Hyprland's live IPC event socket
(`$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock` via
`socat`) for `monitoraddedv2`/`monitoradded` events, and unconditionally runs
`systemctl --user restart hyprpaper.service` a second later whenever one
fires. This covers failure mode #2 (stale surface) automatically. It does
**not** and cannot cover failure mode #1 — if Hyprland itself crashes, you
still need to log back in; once you do, hyprpaper starts fresh with the
correct wallpaper anyway, so no further action is needed there.

An earlier version of this mitigation polled `hyprctl hyprpaper listactive`
every 60s and restarted `hyprpaper` only if it looked wrong — abandoned
because that IPC call was shown to report success while rendering was
actually broken (see 2026-11-10 verification above).

**2026-11-11 update:** a single restart 1s after the reconnect event was
shown to not always fix it — the DRM connector can still be settling, so the
fresh hyprpaper instance binds before things are stable and inherits the
same stale surface. The script now debounces bursts of reconnect events
(3s window) and does two restarts per event (1s, then +4s) instead of one.

Check it's alive: `systemctl --user status wallpaper-watchdog.service`
Check it fired: `journalctl --user -u wallpaper-watchdog.service`

## How to retire this workaround
Once Arch ships `aquamarine 0.15.2` (or later) with the connector-teardown
null-check merged, re-test by cycling TV power several times. If no more
crashes/stale-surface events occur:
```
systemctl --user disable --now wallpaper-watchdog.service
rm ~/.config/systemd/user/wallpaper-watchdog.service
rm ~/.config/systemd/user/graphical-session.target.wants/wallpaper-watchdog.service
rm ~/.config/hypr/scripts/wallpaper-watchdog.sh
```
Track upstream status at https://github.com/hyprwm/aquamarine/issues/383
