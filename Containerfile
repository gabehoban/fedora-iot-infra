# Multi-stage build for Fedora IoT bootc container following official docs
FROM quay.io/fedora-testing/fedora-bootc:rawhide-standard AS builder

# Copy our customization files
COPY systemd/ /tmp/systemd/
COPY scripts/bootc-auto-upgrade /tmp/scripts/bootc-auto-upgrade

# Create manifest with GPS/RTC packages and customizations
RUN cat > /tmp/fedora-iot-gps.yaml << 'EOF'
include: fedora-iot
packages:
  - pps-tools
  - minicom
  - gpsd
  - gpsd-clients
  - chrony
  - i2c-tools

postprocess-script: |
  #!/bin/bash
  set -xeuo pipefail
  
  # Install systemd units and scripts
  cp -r /tmp/systemd/* /target-rootfs/etc/systemd/system/
  cp /tmp/scripts/bootc-auto-upgrade /target-rootfs/usr/local/bin/
  chmod +x /target-rootfs/usr/local/bin/bootc-auto-upgrade

  # Configure kernel modules
  mkdir -p /target-rootfs/etc/modules-load.d
  cat > /target-rootfs/etc/modules-load.d/gps-rtc.conf << 'MODULES'
# I2C modules
i2c-dev
i2c-bcm2835

# RTC module  
rtc-rv3028

# PPS module
pps-gpio
MODULES

  # Configure device tree overlays
  mkdir -p /target-rootfs/boot/firmware/config.txt.d
  cat > /target-rootfs/boot/firmware/config.txt.d/10-gps-rtc.conf << 'DT'
# Enable I2C
dtparam=i2c_arm=on

# RTC Configuration - RV-3028-C7 at address 0x52
dtoverlay=i2c-rtc,rv3028,addr=0x52
dtparam=rtc=off

# PPS Configuration for GPS
dtoverlay=pps-gpio

# Serial configuration for GPS
enable_uart=1
dtparam=uart=on
DT

  # Add i2c group for hardware access (iot user already exists in fedora-iot)
  mkdir -p /target-rootfs/etc/sysusers.d
  cat > /target-rootfs/etc/sysusers.d/iot-hardware.conf << 'SYSUSERS'
# Hardware access for Fedora IoT GPS HAT
g i2c - -
m iot i2c
SYSUSERS

  # Additional hardware configurations
  cat > /target-rootfs/etc/systemd/system/hwclock-sync.service << 'HWCLOCK'
[Unit]
Description=Sync system time with hardware clock
After=systemd-modules-load.service
Before=time-set.target
Wants=time-set.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/hwclock --hctosys
ExecStop=/usr/sbin/hwclock --systohc
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
HWCLOCK

  # GPS init service
  cat > /target-rootfs/etc/systemd/system/gps-init.service << 'GPSINIT'
[Unit]
Description=GPS HAT Initialization
After=systemd-modules-load.service
Before=gpsd.service

[Service]
Type=oneshot
ExecStart=/bin/stty -F /dev/ttyS0 115200 cs8 -cstopb -parenb
ExecStart=/bin/bash -c 'until [ -c /dev/pps0 ]; do sleep 1; done'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
GPSINIT

  # Create hardware configuration files
  cat > /target-rootfs/etc/udev/rules.d/99-gps-rtc.rules << 'UDEV'
# GPS HAT RTC device
KERNEL=="rtc0", SUBSYSTEM=="rtc", ATTRS{name}=="rv3028", SYMLINK+="rtc-gps"

# GPS serial device
KERNEL=="ttyS0", SUBSYSTEM=="tty", SYMLINK+="gps0", MODE="0666"

# PPS device
KERNEL=="pps0", SUBSYSTEM=="pps", SYMLINK+="pps-gps", MODE="0666"
UDEV

  # Configure gpsd
  mkdir -p /target-rootfs/etc/gpsd
  cat > /target-rootfs/etc/gpsd/gpsd.conf << 'GPSD'
# Configuration for gpsd
DEVICES="/dev/ttyS0"
GPSD_OPTIONS="-n -G"
USBAUTO="false"
GPSD

  # Configure chrony for GPS/RTC synchronization
  cat > /target-rootfs/etc/chrony.conf << 'CHRONY'
# Chrony configuration for GPS/RTC synchronization
pool 2.fedora.pool.ntp.org iburst

# GPS/PPS reference clocks
refclock SHM 0 refid GPS precision 1e-1 offset 0.0 delay 0.2
refclock PPS /dev/pps0 refid PPS precision 1e-6

# RTC as fallback
rtcsync

# Other standard chrony settings
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtconutc
CHRONY

  # Customize hwclock-set for RTC support
  cat > /target-rootfs/lib/udev/hwclock-set << 'HWCLOCKSET'
#!/bin/sh
# Customized hwclock-set for RTC hardware support
# Commented out systemd check to allow hardware RTC
# if [ -e /run/systemd/system ] ; then
#     exit 0
# fi

# Commented out to allow hardware RTC to work properly
# /sbin/hwclock --rtc=$dev --systz
HWCLOCKSET
  chmod +x /target-rootfs/lib/udev/hwclock-set

  # Configure services
  systemctl --root=/target-rootfs enable gpsd chronyd hwclock-sync.service gps-init.service bootc-auto-upgrade.timer
  systemctl --root=/target-rootfs disable fake-hwclock || true
EOF

# Build the rootfs using the official bootc builder
RUN /usr/libexec/bootc-base-imagectl build-rootfs --manifest=/tmp/fedora-iot-gps.yaml /target-rootfs

# Final stage: Create the bootc container
FROM scratch
COPY --from=builder /target-rootfs/ /

# Essential bootc labels and configuration following official docs
LABEL containers.bootc 1
LABEL org.opencontainers.image.title="Fedora IoT GPS HAT" \
      org.opencontainers.image.description="Fedora IoT 42 with GPS HAT (u-blox M8 + RV-3028-C7 RTC) support" \
      org.opencontainers.image.vendor="Fedora Project"

ENV container=oci
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]