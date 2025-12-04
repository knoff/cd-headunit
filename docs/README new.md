# Raspberry Pi Headunit Setup — v2.0 (A/B + DATA + FACTORY + Network)

## Goal

- Partition microSD: p1=boot, p2=rootfs_A, p3=rootfs_B, p4=data, p5=factory(ro)
- Clone system to A/B, mount /data for mutable dirs, keep factory image in read-only partition
- Configure dual Wi‑Fi: external client + internal AP tied to USB dongle, Ethernet priority
- Prepare compose stack (MQTT mTLS+ACL, Nginx TLS, MinIO)

## Directory Layout

```text
deploy/pi-setup/
  first-boot/
    00_partition_and_clone.sh
    fstab.template
    relocate-data-bind.mounts
    switch_rootfs.sh
    restore_factory.sh
    init-device-config.sh
    device-init.service
  device.conf.example
deploy/compose/
  docker-compose.yml
  .env.example
  README.md
  certs/mkcerts.sh
  mosquitto/{mosquitto.conf,aclfile}
  nginx/nginx.conf
```

## Windows preparation

1. Flash **Raspberry Pi OS Lite (64-bit)** with Raspberry Pi Imager (enable SSH, set user/pass, Wi‑Fi if needed, hostname).
2. Copy **`deploy/pi-setup/first-boot/`** contents to the boot partition.
3. Copy **`deploy/pi-setup/device.conf.example`** to boot as `device.conf` and edit values (SERIAL, hostname, Wi‑Fi, AP).
4. Create an empty marker file `first-boot.run` on the boot partition.

## First boot flow

- Script partitions the disk, formats p1..p5, clones root → A & B, writes fstab/cmdline, installs helpers and services.
- Reboots into `rootfs_A`.
- `device-init.service` applies `/boot/device.conf` (hostname, user, networks, AP on USB dongle).

## Partitions recap

| Part | Label    | FS   | Mount    | Mode | Size   |
| ---- | -------- | ---- | -------- | ---- | ------ |
| p1   | boot     | vfat | /boot    | rw   | 512 MB |
| p2   | rootfs_A | ext4 | /        | rw   | ~8 GB  |
| p3   | rootfs_B | ext4 | —        | —    | ~8 GB  |
| p4   | data     | ext4 | /data    | rw   | rest   |
| p5   | factory  | ext4 | /factory | ro   | ~3 GB  |

## Network

- **eth0**: preferred if internet available.
- **wlan0**: builtin Wi‑Fi client to external network.
- **wlan1**: USB dongle (TP‑Link WN‑725N) as internal AP (`192.168.50.1/24`).
- Route metrics via `/etc/dhcpcd.exit-hook` enforce priority (eth0 > wlan0).

### `/boot/device.conf` example

See `deploy/pi-setup/device.conf.example`.

## Checklist

- See "✅ Checklist" below (copied from session).

## ✅ Checklist: первичная подготовка Raspberry Pi (A/B + DATA + FACTORY)

**Цель:** разметить microSD с A/B rootfs, `data` и `factory (ro)`, перенести систему и подготовить устройство к запуску стека (MQTT + Nginx + MinIO).

### 1) Подготовка на Windows (Raspberry Pi Imager)

- Записать **Raspberry Pi OS Lite (64-bit)**.
- Параметры:
  - Enable SSH, задать user/password.
  - (Опционально) Wi‑Fi и hostname: `headunit`.
- После записи откроется раздел **`boot`**:
  - Скопировать `deploy/pi-setup/first-boot/`.
  - Скопировать `deploy/pi-setup/device.conf.example` в `device.conf` и заполнить.
  - Создать пустой файл‑триггер: `first-boot.run`.

### 2) Первый запуск Raspberry Pi

- Вставить microSD → подать питание.
- Дождаться автоматической инициализации (2–5 минут) и ребута.

### 3) Верификация

```bash
lsblk -o NAME,LABEL,SIZE,MOUNTPOINT
grep -o 'root=PARTUUID=[^ ]*' /boot/cmdline.txt
cat /etc/fstab
mount | egrep ' /data | /factory | /boot '
```

### 4) Переключение слотов

```bash
sudo switch_rootfs.sh
sudo reboot
```

### 5) Данные

```bash
sudo mkdir -p /data/var_lib_docker /data/var_log /data/srv
sudo systemctl status relocate-data-bind.mounts
```

### 6) Factory (позже)

Положить `/factory/rootfs_A.tar.zst` и `*.sha256` после стабилизации rootfs_A. Восстановление:

```bash
sudo restore_factory.sh        # восстановит A из /factory/rootfs_A.tar.zst
sudo restore_factory.sh B
```

### 7) Сеть

```bash
iw dev
sudo systemctl status device-init.service hostapd dnsmasq
ip route show
```

## Compose quickstart

See `deploy/compose/README.md`.
