------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
hl.monitor({
	output = "HDMI-A-1",
	mode = "3840x2160@60",
	position = "0x0",
	scale = 1,
	bitdepth = 10,
	cm = "hdr", -- or "hdredid" to pull HDR metadata from the display's EDID
	sdr_min_luminance = 0.0,
	sdr_max_luminance = 250,   -- brightness SDR content maps to
	min_luminance = 0.0,
	max_luminance = 800,       -- your TV's peak HDR brightness
})
