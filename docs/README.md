# Документация `cd-headunit` (Raspberry Pi Headunit)

Этот раздел описывает развёртывание, проверку и обслуживание головного устройства кофемашины на базе Raspberry Pi.
Документация разбита на несколько файлов для удобства:

- [install_guide.md](./install_guide.md) — пошаговая установка: от записи образа на microSD до запуска сервисов.
- [post_install_checklist.md](./post_install_checklist.md) — обязательные проверки после первой загрузки.
- [device_conf_guide.md](./device_conf_guide.md) — описание конфигурационного файла `/boot/device.conf` и переменных.
- [naming_conventions.md](./naming_conventions.md) — соглашения по именованию (серийники, SSID, домены).
- [networking_setup.md](./networking_setup.md) — схема сети, приоритеты маршрутов, двухдиапазонная конфигурация.
- [recovery_and_factory.md](./recovery_and_factory.md) — раздел `factory`, бэкапы и восстановление.

> ⚠️ **Обязательно**: все файлы с суффиксом `.example` (например, `device.conf.example`, `.env.example`) нужно скопировать
> и создать **боевые** версии с корректными параметрами (`device.conf`, `.env`). Подробности — в соответствующих документах.
