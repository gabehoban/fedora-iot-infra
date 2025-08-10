# Fedora IoT GPS HAT Configuration

This repository contains a **bootc container** configuration for Fedora IoT 42 with GPS HAT support (u-blox M8 GPS + RV-3028-C7 RTC).

## Hardware Support

- **GPS**: 72-channel u-blox M8 engine at 115200 baud on `/dev/ttyS0`
- **RTC**: Micro Crystal RV-3028-C7 at I2C address 0x52
- **PPS**: Pulse-per-second support via GPIO
- **I2C**: GPS module accessible at address 0x42

## Modern Container-Native Approach

This project uses **Fedora bootc containers** - the modern replacement for OSTree blueprints:

- 🐳 **Container-native** - Standard Docker/Podman tooling
- 🔄 **Atomic updates** - Container-based system updates
- 📦 **Multi-architecture** - ARM64/AMD64 support
- 🧪 **Built-in validation** - Container linting and testing

## Automated CI/CD Pipeline

Images are automatically built, signed, and published via GitHub Actions:

- ✅ **Automated builds** on Containerfile changes and weekly schedule
- ✅ **Multi-platform images** for ARM64 and AMD64 architectures
- ✅ **Cosign signing** with keyless OIDC authentication
- ✅ **SLSA provenance** generation and verification
- ✅ **Container registry** publication to ghcr.io
- ✅ **Bootc validation** and disk image testing

## Quick Deployment

### Container Switch (Existing bootc system)
```bash
# Pull and verify signed container
IMAGE="ghcr.io/gabehoban/fedora-iot-infra/fedora-iot-infra:latest"

cosign verify \
  --certificate-identity-regexp="https://github.com/gabehoban/fedora-iot-infra" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  "$IMAGE"

# Switch to new container
sudo bootc switch "$IMAGE"
sudo systemctl reboot
```

### Disk Image Creation
```bash
# Create bootable disk image
sudo podman run --rm --privileged \
  --security-opt label=type:unconfined_t \
  -v ./output:/output \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type raw \
  ghcr.io/gabehoban/fedora-iot-infra/fedora-iot-infra:latest

# Flash to SD card
sudo dd if=output/disk.raw of=/dev/sdX bs=4M status=progress
```

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed deployment options and troubleshooting.

## Container Configuration

The [Containerfile](Containerfile) includes:
- **Base**: `registry.fedoraproject.org/fedora-bootc:42`
- **Packages**: GPS tools (pps-tools, minicom, gpsd), time sync (chrony), I2C utilities
- **Hardware config**: Device tree overlays for I2C, RTC, PPS, and serial
- **Services**: GPS initialization, hardware clock sync, time synchronization
- **User setup**: Core user with hardware access permissions
- **Validation**: Built-in `bootc container lint`

## Hardware Verification

After deployment:

### Check I2C Devices
```bash
# Should show GPS (0x42) and RTC (0x52/UU)  
sudo i2cdetect -y 1
```

### Test RTC
```bash
# Read hardware clock
sudo hwclock -r -v

# Sync system time to RTC
sudo hwclock -w
```

### Test GPS
```bash
# Monitor GPS data
minicom -b 115200 -o -D /dev/ttyS0

# Or use gpsd clients
cgps
gpsmon
```

### Test PPS
```bash
# Test PPS signal
sudo ppstest /dev/pps0
```

### Check Services
```bash
# Verify services are running
systemctl status gpsd chronyd gps-init hwclock-sync
```

## Development

### Local Build
```bash
# Build container locally
podman build -t fedora-iot-gps .

# Test container
podman run --rm fedora-iot-gps bootc container lint
```

### Updates
```bash
# Check for updates
sudo bootc upgrade --check

# Apply updates
sudo bootc upgrade
sudo systemctl reboot
```

## Migration from Legacy OSTree

If migrating from old OSTree blueprint approach:

```bash
# Clean old rpm-ostree state
sudo rpm-ostree cleanup -m

# Switch to bootc container
sudo bootc switch ghcr.io/gabehoban/fedora-iot-infra/fedora-iot-infra:latest
sudo systemctl reboot
```

## References

- [u-blox M8 Documentation](https://cdn.shopify.com/s/files/1/0835/7707/8094/files/Uputronics_Raspberry_Pi_GPS_RTC_Board_Datasheet_9eec2e77-d368-45ee-acc2-be899ff1d0be.pdf)
- [Fedora IoT Bootc Images](https://docs.fedoraproject.org/en-US/iot/fedora-iot-bootc/)
- [Bootc Documentation](https://docs.fedoraproject.org/en-US/bootc/)
- [Bootc Image Builder](https://github.com/osbuild/bootc-image-builder)
