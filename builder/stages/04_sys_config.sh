#!/bin/bash
# STAGE 04: System Configuration (User, SSH, Network)

log_step "04_sys_config.sh - Configuring OS Environment"

# 1. Подготовка Chroot (Монтирование биндов)
log_info "Mounting system binds for chroot..."

cp /usr/bin/qemu-aarch64-static /mnt/dst/usr/bin/

mount_bind /dev /mnt/dst/dev
mount_bind /dev/pts /mnt/dst/dev/pts
mount_bind /sys /mnt/dst/sys
mount_bind /proc /mnt/dst/proc

export SYS_ENABLE_SSH SYS_USER SYS_PASS NET_HOSTNAME NET_WIFI_SSID NET_WIFI_PASS NET_WIFI_COUNTRY

# ================= START CHROOT =================
cat <<EOF | chroot /mnt/dst /bin/bash
set -e

# --- 0. ОЧИСТКА МУСОРА (CONFLICTING PACKAGES) ---
echo "Purging conflicting packages..."

# Удаляем userconf-pi (мастер настройки пользователя)
# Удаляем cloud-init (облачная настройка, блокирующая консоль)
apt-get remove -y --purge userconf-pi cloud-init || true

# Зачистка следов systemd для надежности
rm -f /usr/lib/systemd/system/userconf-pi.service
rm -f /etc/systemd/system/sysinit.target.wants/userconf-pi.service
rm -rf /usr/lib/userconf-pi
rm -rf /etc/cloud /var/lib/cloud

# Удаляем триггеры
rm -f /boot/firmware/userconf.txt /boot/userconf.txt
rm -f /etc/init.d/apply_noobs_os_config

# Гарантируем, что консоль tty1 включена (иногда cloud-init ее отключает)
systemctl enable getty@tty1.service

# --- A. Hostname ---
echo "Setting hostname: $NET_HOSTNAME"
echo "$NET_HOSTNAME" > /etc/hostname
echo "127.0.0.1 localhost" > /etc/hosts
echo "127.0.1.1 $NET_HOSTNAME" >> /etc/hosts

# --- B. Пользователь и SSH ---
if [ "$SYS_ENABLE_SSH" == "yes" ]; then
    echo "Enabling SSH..."
    systemctl enable ssh

    # Создаем пользователя
    if ! id "$SYS_USER" &>/dev/null; then
        echo "Creating user $SYS_USER..."
        useradd -m -s /bin/bash "$SYS_USER"
        usermod -aG sudo,video,render,input "$SYS_USER"
    fi

    # Пароль
    echo "$SYS_USER:$SYS_PASS" | chpasswd
    echo "root:$SYS_PASS" | chpasswd

    # Удаляем pi
    if [ "$SYS_USER" != "pi" ] && id "pi" &>/dev/null; then
        pkill -u pi || true
        deluser --remove-home pi || true
    fi
else
    echo "SSH disabled by config."
    systemctl disable ssh
fi

# --- C. Настройка Wi-Fi ---
if [ -n "$NET_WIFI_SSID" ]; then
    echo "Configuring Wi-Fi Client: $NET_WIFI_SSID"
    mkdir -p /etc/NetworkManager/system-connections
    chmod 700 /etc/NetworkManager/system-connections

    UUID_WIFI=\$(cat /proc/sys/kernel/random/uuid)

    cat > "/etc/NetworkManager/system-connections/preconfigured-wifi.nmconnection" <<NMEOF
[connection]
id=preconfigured-wifi
uuid=\$UUID_WIFI
type=wifi
interface-name=wlan0
autoconnect=true

[wifi]
mode=infrastructure
ssid=$NET_WIFI_SSID

[wifi-security]
key-mgmt=wpa-psk
psk=$NET_WIFI_PASS

[ipv4]
method=auto

[ipv6]
addr-gen-mode=default
method=auto
NMEOF
    chmod 600 "/etc/NetworkManager/system-connections/preconfigured-wifi.nmconnection"
fi

EOF
# ================= END CHROOT =================

# 3. Уборка
log_info "Unmounting chroot binds..."

rm -f /mnt/dst/usr/bin/qemu-aarch64-static

umount_safe /mnt/dst/proc
umount_safe /mnt/dst/sys
umount_safe /mnt/dst/dev/pts
umount_safe /mnt/dst/dev

log_info "OS Configuration Complete."
