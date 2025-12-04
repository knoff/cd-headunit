# Сетевое окружение

## Интерфейсы и роли

- `eth0` — проводная сеть (приоритетная, если есть интернет).
- `wlan0` — встроенный Wi‑Fi адаптер (клиент внешней сети).
- `wlan1` — USB Wi‑Fi донгл (TP‑Link WN‑725N) — **точка доступа** внутренней сети.

Приоритеты маршрутов задаются через `/etc/dhcpcd.exit-hook`:

- `eth0`: metric 100
- `wlan0`: metric 200

AP получает статический адрес `192.168.50.1/24`.

## Конфигурирование через `/boot/device.conf`

См. [device_conf_guide.md](./device_conf_guide.md). Важные переменные:

- `WIFI_SSID`, `WIFI_PASS` — внешняя сеть;
- `AP_SSID`, `AP_PASS`, `AP_CHANNEL`, `AP_ADDRESS` — внутренняя точка доступа.

## Проверка сети

```bash
iw dev
ip a
ip route show
sudo systemctl status device-init.service hostapd dnsmasq
```

## Связанные сервисы

- `hostapd` — точка доступа;
- `dnsmasq` — DHCP для внутренней сети;
- Docker‑стек: `mosquitto` (8883/tls mTLS+ACL), `nginx` (443/tls), `minio`.
