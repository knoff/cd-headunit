# Чеклист после первой загрузки

## Разметка и монтирование

```bash
lsblk -o NAME,LABEL,SIZE,MOUNTPOINT
grep -o 'root=PARTUUID=[^ ]*' /boot/firmware/cmdline.txt
cat /etc/fstab
mount | egrep ' /data | /factory | /boot '
```

**Ожидаемо:**

- `p1=boot (vfat)`, `p2=rootfs_A (/)`, `p3=rootfs_B`, `p4=/data (ext4, rw)`, `p5=/factory (ext4, ro)`
- В `cmdline.txt` активен `PARTUUID` от **rootfs_A**.

## Bind‑монты и директории данных

```bash
sudo mkdir -p /data/var_lib_docker /data/var_log /data/srv
sudo systemctl status relocate-data-bind.mounts
findmnt -no TARGET,SOURCE,FSTYPE,OPTIONS /var/lib/docker /var/log /srv
```

## Сеть

```bash
hostnamectl
iw dev
ip a
ip route show
sudo systemctl status device-init.service hostapd dnsmasq
```

**Ожидаемо:**

- `eth0` приоритетнее `wlan0` (metrics настроены).
- `wlan1` — точка доступа `cdrXXXXYYYY` на `192.168.50.1/24` (если USB‑донгл присутствует).

## Сервисы стека

```bash
docker ps
curl -k https://localhost/healthz
```

## MQTT mTLS smoke‑test

См. пример в [install_guide.md](./install_guide.md).

## MinIO Console

Зайдите на `https://<PI_IP>/console` и авторизуйтесь (логин/пароль из `.env`).

## Переключение слота (проверка)

```bash
sudo switch_rootfs.sh && sudo reboot
# после перезагрузки убедитесь, что активен другой PARTUUID в /boot/cmdline.txt
```
