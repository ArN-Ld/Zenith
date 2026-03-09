# Changelog

All notable changes to Zenith are documented in this file.

---

## [1.0.0] — 2026-03-09

> First public release, covering 38 development phases.

### Added
- Native SwiftUI menu bar app for macOS 14+.
- Menu bar icon with state-reactive SF Symbol (★ star).
- Dashboard window with golden-ratio proportions (900 × 556).
- Real-time multi-step progress pipeline: MTR latency → download speed → server ranking.
- Results table with sortable columns (server, city, distance, latency, download, score).
- Live log viewer with per-server event stream.
- Settings: reference location geocoder with autocomplete, test parameters, path configuration, geographic zone.
- System preflight window at startup — checks `mtr`, `speedtest-cli`, `mullvad` CLI, and Python.
- Dependency auto-detection for Python, `speedtest-cli`, `mtr`, and Mullvad CLI.
- Runs [vpn-tools](https://github.com/ArN-Ld/vpn-tools) Python CLI as a bundled subprocess via `--machine-readable` JSON protocol.
- Automatic ping fallback when `mtr-packet` is not correctly configured (Homebrew SUID ownership issue).
- Menu bar badge: “ping” capsule indicator when MTR falls back to ping mode.
- Dashboard “Ping mode” label in header subtitle when running in fallback mode.
- Adaptive speedtest timeout: 150 s for servers ≥ 3 000 km away.
- About panel with app version, source links, and dependency credits.
- App icon generated from SF Symbols with multi-resolution `.icns`.
- `build_app.sh` — self-contained release build script bundling Swift binary + Python source + vendored dependencies.
- `generate_icon.py` — reproducible icon generation via Pillow.
- CI workflow: `swift build -c release` on GitHub Actions (macOS).

### Architecture
- **One-way dependency**: `vpn-tools` is a standalone CLI with no knowledge of Zenith. The app invokes it as a subprocess and parses its JSON output.
- `SpeedTestRunner.swift` — subprocess launch, stdin/stdout management, JSON event parsing.
- `SpeedTestViewModel.swift` — MVVM bridge, event routing, UI state machine.
- `DependencyManager.swift` — runtime dependency checks.
- Views: `ContentView` / `MenuBarView` / `ResultsView` / `SettingsView` / `AboutView` / `PreflightCheckView` / `StartupPreflightView`.

### Development history
- 38 phases documented in [DEVLOG.md](DEVLOG.md), from initial audit through UI/UX redesign, JSON protocol migration, location geocoding, and mtr-packet SUID root cause analysis.

### Known Compatibility
- **macOS Homebrew mtr 0.96**: `brew install mtr` may leave `mtr-packet` with incorrect SUID setup (owned by the installing user, not root). Zenith automatically uses ping fallback in this case. See [README § Requirements](README.md#requirements) for the fix.
