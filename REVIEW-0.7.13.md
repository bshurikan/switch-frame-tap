Frame Tap review notes — origin/master @ 3f2f41d (v0.7.13+)
==========================================================

Synced local + fork master to Tomas tip. Old exp/detach-on-home is largely
superseded: upstream already ships detach_on_home default-on.

HOME / SwitchU handoff
----------------------
- applet_mitm_nv.cpp: present-stall detach used 1 s, then PrepareForHomeMenu
- applet_mitm_donor.cpp: 5 s no-reattach hold
- Gap vs goal: SwitchU Album still races vi during that window (black then
  recover). Not "missing the flag" — needs tighter timing (see
  exp/home-handoff-switchu: 200 ms stall / 2.5 s hold + logs).

Network
-------
- applet_mitm_net.cpp: TCP 9950, SysDVR-ish buffers, TCP_NODELAY
- Keyframes: viewer SFTK; network GOP forced to 240 when can_ask
- Gap: mid-join garbage until first SFTK; Wi-Fi-conservative GOP on wired
  (see exp/net-ethernet: auto-IDR on accept, nifm wired → 60 GOP, 320 KB tx)

SwitchU Album capture
---------------------
- Live path attaches to application presents only
- 010000000000100D is a Library Applet — no solid attach on master
- Spike: exp/switchu-album-capture (capture_album=1 / capalbum)

Windows viewer aspect
---------------------
- raw-view.c letterboxes 16:9; 0.7.13 DPI fixes
- Gap: window itself freely resizes (see exp/viewer-aspect-lock WM_SIZING)

Upstream PRs only after OLED soak. Viewer aspect is the safest first PR.
