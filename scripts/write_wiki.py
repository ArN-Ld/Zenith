#!/usr/bin/env python3
"""Write Zenith GitHub Wiki pages to /tmp/Zenith.wiki/"""
from pathlib import Path

wiki = Path("/tmp/Zenith.wiki")
wiki.mkdir(exist_ok=True)

# ─── Installation ────────────────────────────────────────────────────────────
(wiki / "Installation.md").write_text("""\
# Installation

## Requirements

- **macOS 14 Sonoma** or later (Apple Silicon or Intel)
- [Mullvad VPN](https://mullvad.net/download) installed and logged in
- `mtr` *(optional)* — `brew install mtr`\\
  If missing or misconfigured, Zenith automatically falls back to `ping`.

---

## Option 1 — Homebrew Cask *(recommended)*

```bash
brew tap ArN-LaB/tap
brew install --cask zenith
```

Then launch from **Applications** or Spotlight (`Zenith`).

---

## Option 2 — Build from source

Requires Xcode Command Line Tools or Xcode 15+.

```bash
git clone https://github.com/ArN-LaB/Zenith.git
cd Zenith
bash build_app.sh
cp -R 'Zenith.app' /Applications/
open '/Applications/Zenith.app'
```

`build_app.sh` compiles the Swift binary in release mode and bundles Python\\
dependencies (`speedtest-cli`, `geopy`, `colorama`) automatically.

---

## First launch — Gatekeeper

The app is currently **unsigned**. macOS will block the first open.

> **Right-click (or Ctrl-click) → Open → Open**

You only need to do this once. After that, Zenith launches normally.

---

## Updating

### Homebrew
```bash
brew upgrade --cask zenith
```

### Manual
Re-run `build_app.sh` from the updated repo and copy `Zenith.app` to Applications again.

Zenith also shows an **update badge** in the About tab whenever a new GitHub release is available.
""", encoding="utf-8")

# ─── User Guide ──────────────────────────────────────────────────────────────
(wiki / "User-Guide.md").write_text("""\
# User Guide

## Overview

Zenith lives in your **menu bar** as a ★ icon. Click it to open the popover.

From there you can:
- Start a speed test (standard or calibration)
- Watch results appear in real time
- Open the full dashboard for detailed results and settings

---

## First run — Settings

Before the first test, configure your **reference location**:

1. Click ★ in the menu bar
2. Click the **gear icon** (⚙) to open Settings
3. In the **Location** field, type your city (e.g. `Paris`) — autocomplete suggests results
4. Select your city and click **Save**

Zenith uses this location to compute the distance to each Mullvad server and weight the score accordingly.

You can also adjust:
| Setting | Description |
|---------|-------------|
| **Max servers** | How many servers to test (default: 10) |
| **Speed test duration** | Seconds per download test (default: 5 s) |
| **MTR / ping path** | Custom binary paths if not in standard locations |

---

## Starting a test

### Standard test
Click **Start test** in the popover. Zenith will:

1. **Connect** — verify Mullvad CLI is reachable
2. **Fetch servers** — pull the current server list from Mullvad
3. **Latency (MTR/ping)** — measure round-trip time to each candidate server
4. **Speed test** — run a download benchmark on the top candidates
5. **Results** — rank servers by a combined latency + speed score

### Calibration test
Click **Calibrate** (or select it in Settings). This runs a shorter, single-server test\\
to verify your download baseline before a full run. Useful after changing location\\
or network conditions.

---

## Reading the results

The **Results** tab shows a ranked table:

| Column | Meaning |
|--------|---------|
| **Server** | Mullvad server hostname · Continent |
| **City** | City and country |
| **Distance** | Distance from your reference location (km) |
| **Latency** | Average round-trip time (ms) |
| **Speed** | Download speed (Mbit/s) |
| **Score** | Combined ranking score (lower = better) |

Click any column header to sort. The top row is the recommended server.

---

## Live log

The **Log** tab streams every event from the test in real time:\\
server connections, latency results, speed samples, errors.

Useful to diagnose why a server scored poorly.

---

## Menu bar icon states

| Icon | Meaning |
|------|---------|
| ★ (outline) | Idle — no test running |
| ★ (filled, pulsing) | Test in progress |
| ★ (filled) | Test complete |
| ★ (orange) | Warning / ping fallback active |
| ★ (red) | Error — check the log |

---

## About tab

Shows the app version, links to the source repos, and dependency credits.\\
An **update badge** appears inline next to the version when a new release is available on GitHub.\\
A download counter shows total installs across all releases.
""", encoding="utf-8")

# ─── Troubleshooting ─────────────────────────────────────────────────────────
(wiki / "Troubleshooting.md").write_text("""\
# Troubleshooting

## App won't open — "unidentified developer"

macOS blocks unsigned apps by default.

**Fix:** Right-click (or Ctrl-click) the app → **Open** → **Open**.\\
You only need to do this once.

---

## "mtr-packet: operation not permitted" / ping fallback active

`brew install mtr` leaves `mtr-packet` owned by your user account instead of root,\\
which prevents it from opening raw sockets. Zenith detects this and falls back to\\
`ping` automatically. Full hop-by-hop MTR tracing is disabled in fallback mode.

**Fix (optional):**
```bash
sudo chown root:wheel $(brew --prefix)/Cellar/mtr/0.96/sbin/mtr-packet
sudo chmod 4755 $(brew --prefix)/Cellar/mtr/0.96/sbin/mtr-packet
```
Restart Zenith after running this.

---

## "Mullvad CLI not found"

Zenith requires the Mullvad desktop app (which ships `mullvad` CLI).

**Fix:** Install [Mullvad VPN](https://mullvad.net/download), launch it once, and log in.

---

## "speedtest-cli not found"

The correct binary should be bundled inside `Zenith.app/Contents/Resources/python/vendor/`.

**Fix:** If you built from source, re-run `bash build_app.sh` — it re-vendors all dependencies.

---

## Test hangs or never completes

- Check that **Mullvad is connected** (or at least the CLI is accessible).
- Try reducing **Max servers** in Settings (fewer servers = faster test).
- Check the **Log** tab for the last event to see where it stopped.
- If using MTR, try toggling the **ping fallback** in Settings.

---

## No servers appear in results

- Ensure your reference location is set correctly in Settings.
- Check your internet connection and that Mullvad is not blocking outbound connections.
- Open the Log tab — it will show any API or subprocess errors.

---

## Calibration step never turns orange / progress stalls

This was a bug in versions before `v1.1.0`. Update to the latest release.

---

## Still stuck?

Open an issue on [GitHub](https://github.com/ArN-LaB/Zenith/issues) with:\\
- macOS version
- Zenith version (About tab)
- The contents of the Log tab
""", encoding="utf-8")

print("Wiki pages written:")
for f in sorted(wiki.iterdir()):
    print(f"  {f.name} ({f.stat().st_size} bytes)")
