# Соглашения по именованию

## Серийный номер

Формат: **`CDR-XXXXYYYY`**, где:

- `XXXX` — серия/партия/ревизия,
- `YYYY` — порядковый номер кофемашины в серии.

**Примеры:**

- `CDR-12340001`
- `CDR-20250042`

## Hostname

Рекомендуемый формат: `headunit-XXXXYYYY`

## Точка доступа (SSID)

Формат: **`cdrXXXXYYYY`** (в нижнем регистре).

- Для устройства с номером `CDR-12340001` → `cdr12340001`.

## MINIO_DOMAIN

Формат: **`cdrXXXXYYYY.local`**.

- Для `CDR-12340001` → `cdr12340001.local`.

Связанные места использования:

- `device.conf`: `AP_SSID=cdrXXXXYYYY`
- `.env` для compose: `MINIO_DOMAIN=cdrXXXXYYYY.local`
