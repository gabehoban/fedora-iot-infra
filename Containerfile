# Fedora IoT 42 Bootc Container with GPS HAT Support
FROM registry.fedoraproject.org/fedora-bootc:42

# Install GPS/RTC packages
RUN dnf install -y \
    pps-tools \
    minicom \
    gpsd \
    gpsd-clients \
    chrony \
    i2c-tools \
    && dnf clean all

# Create GPS/RTC kernel modules configuration
RUN mkdir -p /etc/modules-load.d && \
    cat > /etc/modules-load.d/gps-rtc.conf << 'EOF'
# I2C modules
i2c-dev
i2c-bcm2835

# RTC module  
rtc-rv3028

# PPS module
pps-gpio
EOF

# Configure device tree overlays for Raspberry Pi
RUN mkdir -p /boot/firmware/config.txt.d && \
    cat > /boot/firmware/config.txt.d/10-gps-rtc.conf << 'EOF'
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
EOF

# Create hwclock sync service
RUN cat > /etc/systemd/system/hwclock-sync.service << 'EOF'
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
EOF

# Create GPS initialization service
RUN cat > /etc/systemd/system/gps-init.service << 'EOF'
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
EOF

# Create udev rules for GPS/RTC devices
RUN cat > /etc/udev/rules.d/99-gps-rtc.rules << 'EOF'
# GPS HAT RTC device
KERNEL=="rtc0", SUBSYSTEM=="rtc", ATTRS{name}=="rv3028", SYMLINK+="rtc-gps"

# GPS serial device
KERNEL=="ttyS0", SUBSYSTEM=="tty", SYMLINK+="gps0", MODE="0666"

# PPS device
KERNEL=="pps0", SUBSYSTEM=="pps", SYMLINK+="pps-gps", MODE="0666"
EOF

# Configure gpsd
RUN mkdir -p /etc/gpsd && \
    cat > /etc/gpsd/gpsd.conf << 'EOF'
# Configuration for gpsd
DEVICES="/dev/ttyS0"
GPSD_OPTIONS="-n -G"
USBAUTO="false"
EOF

# Configure chrony for GPS/RTC synchronization
RUN cat > /etc/chrony.conf << 'EOF'
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
EOF

# Customize hwclock-set for RTC support
RUN cat > /lib/udev/hwclock-set << 'EOF'
#!/bin/sh
# Customized hwclock-set for RTC hardware support
# Commented out systemd check to allow hardware RTC
# if [ -e /run/systemd/system ] ; then
#     exit 0
# fi

# Commented out to allow hardware RTC to work properly
# /sbin/hwclock --rtc=$dev --systz
EOF
RUN chmod +x /lib/udev/hwclock-set

# Copy auto-upgrade scripts
COPY systemd/ /etc/systemd/system/
COPY scripts/bootc-auto-upgrade /usr/local/bin/bootc-auto-upgrade
RUN chmod +x /usr/local/bin/bootc-auto-upgrade

# Enable required services
RUN systemctl enable gpsd chronyd hwclock-sync.service gps-init.service && \
    systemctl enable bootc-auto-upgrade.timer && \
    systemctl disable fake-hwclock || true

# Create hardware access groups and core user
RUN groupadd -f dialout && \
    groupadd -f i2c && \
    groupadd -f tty && \
    useradd -m -G wheel,dialout,i2c,tty -s /bin/bash core

# Add container labels
LABEL org.opencontainers.image.title="Fedora IoT GPS HAT" \
      org.opencontainers.image.description="Fedora IoT 42 with GPS HAT (u-blox M8 + RV-3028-C7 RTC) support" \
      org.opencontainers.image.vendor="Fedora Project" \
      org.opencontainers.image.base.name="registry.fedoraproject.org/fedora-bootc:42"

# Run bootc container lint as final validation
RUN bootc container lint