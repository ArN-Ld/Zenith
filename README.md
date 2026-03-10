# Zenith

> Find your peak VPN performance — right from the menu bar.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black?logo=apple)
![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange?logo=swift)
![License: MIT](https://img.shields.io/badge/License-MIT-blue)

**Zenith** is a native macOS menu bar app that ranks [Mullvad VPN](https://mullvad.net) servers by latency and download speed. It runs [**vpn-tools**](https://github.com/ArN-LaB/vpn-tools) as a bundled subprocess and surfaces the results in a clean SwiftUI interface.

The name comes from astronomy: the **zenith** is the highest point in the sky — just like Zenith finds the peak-performing server for you.

---

## Features

- **Menu bar icon** with live state indicator (idle / running / done / error)
- **Multi-step pipeline**: MTR latency → download speed calibration → server ranking
- **Results table** — sortable by city, distance, latency, speed, score
- **Live log** — per-server event stream in real time
- **Ping fallback** — automatic when `mtr-packet` has a Homebrew ownership issue (see below)
- **Adaptive timeout** — 150 s for servers ≥ 3 000 km away
- **Settings** — reference location geocoder with autocomplete, test parameters, path configuration
- **System preflight** — checks `mtr`, `speedtest-cli`, `mullvad` CLI, and Python at startup
- **About panel** — version, source links, dependency credits

---

## Requirements

- macOS 14 Sonoma or later (Apple Silicon or Intel)
- [Mullvad VPN](https://mullvad.net/download) installed and logged in
- Python 3.9+ with `speedtest-cli` and `geopy` — bundled automatically by `build_app.sh`
- `mtr` — `brew install mtr` *(optional — ping fallback activates automatically if missing or misconfigured)*

### mtr note (Homebrew)

> **Upstream bug:** Homebrew's `mtr` formula does not set the required SUID bit on `mtr-packet` after installation.
> This is a known issue tracked at [homebrew-core#271391](https://github.com/Homebrew/homebrew-core/issues/271391).
> The workaround below remains necessary until the formula is fixed.

`brew install mtr` may leave `mtr-packet` with incorrect SUID ownership (owned by the
installing user instead of root). The app automatically uses ping fallback in that case.
To fix MTR for full hop tracking, run once:

```bash
sudo chown root:wheel $(brew --prefix)/Cellar/mtr/0.96/sbin/mtr-packet
sudo chmod 4755 $(brew --prefix)/Cellar/mtr/0.96/sbin/mtr-packet
```

---

## Installation

### Manual (build from source)

Requires Xcode Command Line Tools / Swift 5.9+.

```bash
git clone https://github.com/ArN-LaB/Zenith.git
cd Zenith
bash build_app.sh
cp -R 'Zenith.app' /Applications/
open '/Applications/Zenith.app'
```

`build_app.sh` compiles the Swift binary in release mode and bundles the Python source
and vendored dependencies (`speedtest-cli`, `geopy`, `colorama`) automatically.
No separate Python environment needed.

### Homebrew Cask

```bash
brew tap ArN-LaB/tap
brew install --cask zenith
```

> Note: the app is currently **unsigned**. macOS will show a Gatekeeper warning on first launch.
> Right-click (or Control-click) → **Open** to bypass it once.
> A notarized build will follow when a developer certificate is available.

---

## Architecture

```
vpn-tools (Python CLI)          Zenith.app (this project, Swift)
────────────────────────        ──────────────────────────────────────
mullvad_speed_test.py           SpeedTestRunner.swift
  --machine-readable              └─ launches Python subprocess
  → stdout: JSON lines            └─ parses JSON lines from stdout
                                       └─ feeds SpeedTestViewModel
                                            └─ drives SwiftUI views
```

The dependency is **one-way**: `vpn-tools` is a standalone CLI with no knowledge of this
app. Zenith invokes it as a subprocess and consumes its `--machine-readable` JSON protocol.

| Concern | Where it lives |
|---------|----------------|
| Speed test logic | `vpn-tools` — `mullvad_speed_test.py` |
| Server coordinates | `vpn-tools` — `data/coordinates.json` |
| MTR / ping fallback | `vpn-tools` |
| JSON protocol spec | `vpn-tools` — `CHANGELOG.md` |
| macOS UI, menu bar | This project |
| Subprocess launch & parsing | `SpeedTestRunner.swift` |
| Dependency checks | `DependencyManager.swift` |

---

## Project structure

```
Zenith/
├── Package.swift
├── build_app.sh              ← release build + bundle
├── CHANGELOG.md
├── docs/
│   └── DEVLOG.md             ← full phase-by-phase dev history
├── scripts/
│   └── generate_icon.py      ← regenerate app icon (requires Pillow)
├── Resources/
│   └── Zenith.icns
└── Sources/Zenith/
    ├── VPNToolsApp.swift
    ├── Models/
    │   ├── SpeedTestModels.swift
    │   └── SpeedTestViewModel.swift
    ├── Services/
    │   ├── DependencyManager.swift
    │   ├── LocationResolver.swift
    │   ├── SpeedTestRunner.swift
    │   └── UpdateChecker.swift
    └── Views/
        ├── AboutView.swift
        ├── ContentView.swift
        ├── MenuBarView.swift
        ├── PreflightCheckView.swift
        ├── ResultsView.swift
        ├── SettingsView.swift
        └── StartupPreflightView.swift
```

---

## Documentation

Full user documentation is on the **[Wiki](https://github.com/ArN-LaB/Zenith/wiki)**:

- [Installation](https://github.com/ArN-LaB/Zenith/wiki/Installation)
- [User Guide](https://github.com/ArN-LaB/Zenith/wiki/User-Guide)
- [Troubleshooting](https://github.com/ArN-LaB/Zenith/wiki/Troubleshooting)

---

## Contributing

Bug reports and feature requests welcome via [GitHub Issues](https://github.com/ArN-LaB/Zenith/issues).

- Test logic / CLI changes → [vpn-tools](https://github.com/ArN-LaB/vpn-tools)
- macOS UI / Swift changes → this repo

When `vpn-tools` ships a protocol change, update `SpeedTestRunner.swift` and
`SpeedTestModels.swift`, then document the change in `docs/DEVLOG.md` under a new phase
with a `> Prérequis vpn-tools :` note.

---

## License

MIT — see [LICENSE](LICENSE).
Bundles [vpn-tools](https://github.com/ArN-LaB/vpn-tools) — MIT License © 2025 Valera.
