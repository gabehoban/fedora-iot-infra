# Fedora IoT GPS HAT Configuration

This repository contains an OSTree blueprint for configuring Fedora IoT with GPS HAT support (u-blox M8 GPS + RV-3028-C7 RTC).

## Hardware Support

- **GPS**: 72-channel u-blox M8 engine at 115200 baud on `/dev/ttyS0`
- **RTC**: Micro Crystal RV-3028-C7 at I2C address 0x52
- **PPS**: Pulse-per-second support via GPIO
- **I2C**: GPS module accessible at address 0x42

## Automated CI/CD Pipeline

Images are automatically built, signed, and published via GitHub Actions:

- ✅ **Automated builds** on blueprint changes and weekly schedule
- ✅ **Cosign signing** with keyless OIDC authentication  
- ✅ **SLSA provenance** generation and verification
- ✅ **Container registry** publication to ghcr.io
- ✅ **Security scanning** and signature verification

### Quick Deployment

```bash
# Pull latest signed image
IMAGE="ghcr.io/gabehoban/fedora-iot-infra/fedora-iot-infa:latest"

# Verify signature
cosign verify \
  --certificate-identity-regexp="https://github.com/gabehoban/fedora-iot-infra" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  $IMAGE

# Deploy to device
skopeo copy docker://$IMAGE dir:fedora-iot-infa
sudo ostree pull-local fedora-iot-infa/ostree-repo fedora-iot-infa
sudo rpm-ostree rebase fedora-iot-infa
```

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed deployment options and troubleshooting.

## Verification

After deployment and reboot:

### Check I2C Devices
```bash
# Should show GPS (0x42) and RTC (0x52/UU)
sudo i2cdetect -y 1
```

### Test RTC
```bash
# Read hardware clock
sudo hwclock -r -v

# Write system time to RTC
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

## Configuration Details

The blueprint includes:

- **Packages**: pps-tools, minicom, gpsd, chrony, i2c-tools
- **Kernel modules**: i2c-dev, i2c-bcm2835, rtc-rv3028, pps-gpio
- **Device tree overlays**: i2c-rtc, pps-gpio
- **Services**: GPS initialization, hardware clock sync
- **Time synchronization**: Chrony with GPS/PPS/RTC sources
- **Hardware access**: User permissions for dialout, i2c groups

## Troubleshooting

### RTC Issues
If experiencing voltage low errors:
```bash
# Check RTC registers (may need configure-rv3028.sh script)
sudo hwclock -r -v
```

### GPS Not Responding
```bash
# Check serial port configuration
stty -F /dev/ttyS0

# Verify device permissions
ls -l /dev/ttyS0 /dev/gps0
```

### PPS Not Working
```bash
# Check PPS device exists
ls -l /dev/pps*

# Verify kernel modules loaded
lsmod | grep pps
```

## References

- [u-blox M8 Documentation](https://store.uputronics.com/files/UBX-13003221.pdf)
- [Fedora IoT Documentation](https://docs.fedoraproject.org/en-US/iot/)
- [OSTree Blueprint Reference](https://osbuild.org/docs/user-guide/blueprint-reference/)