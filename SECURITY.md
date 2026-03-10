# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.0.x   | ✅         |

## Reporting a Vulnerability

**Do not open a public GitHub issue for security vulnerabilities.**

Please report security issues privately via
[GitHub Security Advisories](https://github.com/ArN-LaB/Zenith/security/advisories/new).

You will receive a response within 7 days.

## Scope

Security issues relevant to this project:

- Local subprocess argument injection (Python subprocess invocation)
- Bundle integrity of vendored Python packages
- Network operations: Mullvad CLI, speedtest, MTR, ping
- Credential or location data exposure in logs

## Out of Scope

- Vulnerabilities in upstream dependencies (`speedtest-cli`, `geopy`, `mtr`, Mullvad CLI) — report those to the respective projects.
- Denial-of-service via local resource exhaustion.
- Network-level attacks on the VPN infrastructure itself — report those to Mullvad.
