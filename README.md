# Fedora IoT GPS HAT Bootc Container

Fedora IoT bootc container with support for GPS HAT (u-blox M8 GPS + RV-3028-C7 RTC) on Raspberry Pi.

## Latest Image

**Container**: `ghcr.io/gabehoban/fedora-iot-infra/fedora-iot-infra:main`

**Digest**: `ghcr.io/gabehoban/fedora-iot-infra/fedora-iot-infra@sha256:4af402d8c25269f066f57a46b7747e1b10baa4d19ca035bd8de42a7b52d2a12d`

**Last Updated**: $(date -u '+%Y-%m-%d %H:%M:%S UTC')

## Quick Start

### Deploy to existing Fedora IoT system:

```bash
# Switch to this bootc container
sudo bootc switch ghcr.io/gabehoban/fedora-iot-infra/fedora-iot-infra:main
sudo systemctl reboot
```

### Or use the specific digest:

```bash
sudo bootc switch ghcr.io/gabehoban/fedora-iot-infra/fedora-iot-infra@sha256:4af402d8c25269f066f57a46b7747e1b10baa4d19ca035bd8de42a7b52d2a12d
sudo systemctl reboot
```

## Features

- u-blox M8 GPS support (UART, I2C)
- RV-3028-C7 RTC support
- PPS (Pulse Per Second) support for precise timing
- Automatic bootc updates via systemd timer
- Pre-configured gpsd and chrony for time synchronization
- Fedora IoT base with IoT-specific packages

## Hardware Configuration

- **GPS**: u-blox M8 on I2C address 0x42, UART at 115200 baud
- **RTC**: RV-3028-C7 on I2C address 0x52
- **PPS**: GPIO pin for precise timing

## Default User

- Username: `iot`
- Groups: `wheel`, `dialout`, `i2c`
- SSH keys should be added during initial deployment

## Automatic Updates

The container includes automatic update checking every 6 hours with scheduled reboots at 3 AM if updates are available.

## Build Status

![Build Status](https://github.com/gabehoban/fedora-iot-infra/actions/workflows/bootc-build.yml/badge.svg)

## Verification

Verify container signatures:

```bash
cosign verify \
  --certificate-identity-regexp="https://github.com/gabehoban/fedora-iot-infra" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  ghcr.io/gabehoban/fedora-iot-infra/fedora-iot-infra@sha256:4af402d8c25269f066f57a46b7747e1b10baa4d19ca035bd8de42a7b52d2a12d
```

## License

This project follows Fedora licensing.
