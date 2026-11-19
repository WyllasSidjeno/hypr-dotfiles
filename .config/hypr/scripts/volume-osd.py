#!/usr/bin/env python3
"""Circular volume OSD for Hyprland, styled to match the waybar Vesper theme.

Run with --notify PCT MUTED to show/update the popup (auto-spawns the
background daemon on first use). Run with --daemon to start the daemon
directly (the --notify path does this for you).
"""
import math
import os
import socket
import subprocess
import sys
import threading
import time

SOCK_PATH = f"/run/user/{os.getuid()}/volume-osd.sock"

# Vesper theme colors (see ~/.config/waybar/style.css)
BG = (16 / 255, 16 / 255, 16 / 255, 0.9)
BORDER = (255 / 255, 199 / 255, 153 / 255, 0.18)
TRACK = (160 / 255, 160 / 255, 160 / 255, 0.25)
ACCENT = (255 / 255, 199 / 255, 153 / 255, 1.0)
MUTED = (255 / 255, 128 / 255, 128 / 255, 1.0)
FG = (1.0, 1.0, 1.0, 1.0)

SIZE = 150
HOLD_MS = 1200
FADE_MS = 250


def send_notify(pct: int, muted: bool) -> None:
    msg = f"{pct}:{int(muted)}\n".encode()
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
            s.settimeout(0.3)
            s.connect(SOCK_PATH)
            s.sendall(msg)
            return
    except OSError:
        pass

    subprocess.Popen(
        [sys.executable, os.path.abspath(__file__), "--daemon"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )

    for _ in range(40):
        time.sleep(0.05)
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                s.settimeout(0.3)
                s.connect(SOCK_PATH)
                s.sendall(msg)
                return
        except OSError:
            continue


def run_daemon() -> None:
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as probe:
            probe.settimeout(0.2)
            probe.connect(SOCK_PATH)
        return  # another daemon is already alive
    except OSError:
        pass
    try:
        os.unlink(SOCK_PATH)
    except FileNotFoundError:
        pass

    import gi

    gi.require_version("Gtk", "4.0")
    gi.require_version("Pango", "1.0")
    gi.require_version("PangoCairo", "1.0")
    from gi.repository import GLib, Gtk, Pango, PangoCairo

    GLib.set_prgname("volume-osd")
    Gtk.init()

    state = {"pct": 0, "muted": False}
    hide_timer = {"id": None}
    fade_timer = {"id": None}

    win = Gtk.Window()
    win.set_decorated(False)
    win.set_resizable(False)
    win.set_default_size(SIZE, SIZE)
    win.set_can_focus(False)

    css = Gtk.CssProvider()
    css.load_from_string("window { background: transparent; }")
    Gtk.StyleContext.add_provider_for_display(
        win.get_display(), css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    )

    def on_draw(area, cr, width, height, *_args):
        cx, cy = width / 2, height / 2
        r_outer = min(width, height) / 2 - 6
        r_ring = r_outer - 10

        cr.set_line_width(1.5)
        cr.arc(cx, cy, r_outer, 0, 2 * math.pi)
        cr.set_source_rgba(*BG)
        cr.fill_preserve()
        cr.set_source_rgba(*BORDER)
        cr.stroke()

        cr.set_line_width(8)
        cr.set_line_cap(1)  # ROUND
        cr.arc(cx, cy, r_ring, 0, 2 * math.pi)
        cr.set_source_rgba(*TRACK)
        cr.stroke()

        if state["muted"]:
            cr.arc(cx, cy, r_ring, 0, 2 * math.pi)
            cr.set_source_rgba(*MUTED)
            cr.stroke()
        elif state["pct"] > 0:
            frac = max(0.0, min(1.0, state["pct"] / 100.0))
            start = -math.pi / 2
            end = start + frac * 2 * math.pi
            cr.arc(cx, cy, r_ring, start, end)
            cr.set_source_rgba(*ACCENT)
            cr.stroke()

        label = "Muted" if state["muted"] else f"{state['pct']}"
        layout = PangoCairo.create_layout(cr)
        layout.set_text(label, -1)
        font = Pango.FontDescription()
        font.set_family("Noto Sans")
        font.set_weight(Pango.Weight.BOLD)
        font.set_size(int((26 if not state["muted"] else 16) * Pango.SCALE))
        layout.set_font_description(font)
        _, log_rect = layout.get_pixel_extents()
        cr.set_source_rgba(*FG)
        cr.move_to(cx - log_rect.width / 2, cy - log_rect.height / 2)
        PangoCairo.show_layout(cr, layout)

    area = Gtk.DrawingArea()
    area.set_content_width(SIZE)
    area.set_content_height(SIZE)
    area.set_draw_func(on_draw)
    win.set_child(area)

    def cancel_timers():
        if hide_timer["id"] is not None:
            GLib.source_remove(hide_timer["id"])
            hide_timer["id"] = None
        if fade_timer["id"] is not None:
            GLib.source_remove(fade_timer["id"])
            fade_timer["id"] = None

    def start_fade():
        win.set_opacity(1.0)
        steps = {"n": 0}
        total = max(1, FADE_MS // 20)

        def step():
            steps["n"] += 1
            win.set_opacity(max(0.0, 1.0 - steps["n"] / total))
            if steps["n"] >= total:
                win.set_visible(False)
                fade_timer["id"] = None
                return False
            return True

        fade_timer["id"] = GLib.timeout_add(20, step)
        hide_timer["id"] = None
        return False

    def show_popup(pct: int, muted: bool):
        cancel_timers()
        state["pct"] = pct
        state["muted"] = muted
        area.queue_draw()
        win.set_opacity(1.0)
        win.set_visible(True)
        win.present()
        hide_timer["id"] = GLib.timeout_add(HOLD_MS, start_fade)
        return False

    def server_loop():
        srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        srv.bind(SOCK_PATH)
        srv.listen(8)
        while True:
            conn, _ = srv.accept()
            with conn:
                data = b""
                while True:
                    chunk = conn.recv(64)
                    if not chunk:
                        break
                    data += chunk
            line = data.decode().strip().splitlines()[-1] if data else ""
            try:
                pct_s, muted_s = line.split(":")
                pct, muted = int(pct_s), bool(int(muted_s))
            except (ValueError, IndexError):
                continue
            GLib.idle_add(show_popup, pct, muted)

    threading.Thread(target=server_loop, daemon=True).start()

    win.set_visible(False)
    GLib.MainLoop().run()


def main() -> None:
    if "--daemon" in sys.argv:
        run_daemon()
        return
    if "--notify" in sys.argv:
        i = sys.argv.index("--notify")
        pct = int(sys.argv[i + 1])
        muted = bool(int(sys.argv[i + 2]))
        send_notify(pct, muted)
        return
    print(__doc__)


if __name__ == "__main__":
    main()
