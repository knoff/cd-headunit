# Пошаговая установка (Install Guide)

Цель — подготовить Raspberry Pi для кофемашины с разметкой **A/B + DATA + FACTORY**, базовой сетью и минимальным стеком сервисов (MQTT mTLS+ACL, Nginx TLS, MinIO).

## 1. Подготовка образа на Windows (Raspberry Pi Imager)

1. Скачайте и установите **Raspberry Pi Imager**.
2. Запишите **Raspberry Pi OS Lite (64-bit)** _(находится в разделе **Raspberry Pi OS (other)**)_ на microSD.
3. В параметрах Imager включите:
   - `Enable SSH`, задайте пользователя/пароль;
   - (опционально) Wi‑Fi и hostname (например, `headunit`).
4. По окончании запись откроется раздел `boot` (FAT32).

## 2. Копирование первичных файлов на `boot`

Скопируйте на смонтированный раздел `boot` _(или `bootfs` в зависимости от версии Raspberry Pi Imager)_:

- содержимое каталога `deploy/pi-setup/first-boot/` из репозитория:
  - `00_partition_and_clone.sh` — разметка p1..p5, клонирование rootfs в **A/B**, генерация `fstab`/`cmdline.txt`;
  - `fstab.template`, `relocate-data-bind.mounts` — схема монтирования `/data`, `/factory` (ro) и bind-монтов;
  - `switch_rootfs.sh`, `restore_factory.sh` — переключение A↔B и восстановление из `factory`;
  - `init-device-config.sh`, `device-init.service` — настройка hostname, пользователя и сети из `/boot/device.conf`.
- **создайте пустой файл** `first-boot.run` (маркер запуска инициализации);
- из каталога `deploy/pi-setup/` скопируйте **`device.conf.example`** и сохраните как **`device.conf`**, затем **заполните** значения.
  Подробности — см. [device_conf_guide.md](./device_conf_guide.md).

## 3. Первая загрузка Raspberry Pi

1. Вставьте microSD в Raspberry Pi и подайте питание.
2. Подождите 2–5 минут — выполнится:
   - переразметка: `p1=boot`, `p2=rootfs_A`, `p3=rootfs_B`, `p4=data`, `p5=factory (ro)`;
   - клонирование текущей системы в **A** и **B**;
   - установка `fstab` и активация systemd-юнитов;
   - перезагрузка в `rootfs_A`.
3. После ребута подключитесь по SSH (hostname/IP).

## 4. Проверки после первой загрузки

Выполните шаги из [post_install_checklist.md](./post_install_checklist.md).

## 5. Настройка сети и приоритетов

- Концепция: `eth0` — приоритетная (если есть интернет), `wlan0` — клиент внешней Wi‑Fi сети, `wlan1` — точка доступа (USB‑донгл).
- Подробно — в [networking_setup.md](./networking_setup.md).
- Параметры берутся из `/boot/device.conf` — см. [device_conf_guide.md](./device_conf_guide.md).

## 6. Подготовка TLS и Compose‑стека (MQTT, Nginx, MinIO)

1. Сгенерируйте сертификаты:
   ```bash
   cd deploy/compose/certs && ./mkcerts.sh
   ```
2. Скопируйте `deploy/compose/.env.example` в **`deploy/compose/.env`** и **заполните** значения:
   - `MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD` — учётные данные MinIO;
   - `MINIO_DOMAIN` — используйте соглашения, см. [naming_conventions.md](./naming_conventions.md).
3. Запустите стек:
   ```bash
   cd deploy/compose
   docker compose up -d
   ```
4. Проверка:
   - MinIO Console: `https://<PI_IP>/console` (логин/пароль из `.env`);
   - MQTT mTLS publish:
     ```bash
     mosquitto_pub -h <PI_IP> -p 8883 -t "telemetry/test" -m "hello"       --cafile certs/ca/ca.crt       --cert certs/clients/headunit/client.crt       --key certs/clients/headunit/client.key
     ```

## 7. Создание заводского образа (позже)

После стабилизации **rootfs_A** сформируйте `rootfs_A.tar.zst` и разместите в `/factory`.
Шаги и рекомендации — в [recovery_and_factory.md](./recovery_and_factory.md).
