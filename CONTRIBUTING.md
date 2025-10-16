# Руководство по участию в разработке

## 🔀 Ветвление

- `main` — стабильная ветка релиза
- `develop` — основная ветка разработки
- `feature/<name>` — новые функции
- `fix/<name>` — исправления
- `docs/<name>` — документация

## 📝 Коммиты

Формат:

```text
<type>(<scope>): <message>
```

Примеры:

```text
feat(core): add OTA update logic
fix(rpk_pump): correct PWM calibration
docs: update architecture diagram
```

Типы: feat, fix, chore, refactor, docs, test.

## 🧰 Code style

- Python — Black + Ruff
- JS/TS — Prettier
- C/C++ — Clang-format
- Markdown — Markdownlint
- Все изменения проходят через `pre-commit`

## ✅ Pull Requests

1. Перед PR: `pre-commit run --all-files`, тесты зелёные
2. PR с кратким описанием цели и контекста
3. Merge через squash после апрува

## 🧪 Тесты и линтеры

- `pytest -q` / `npm test` / `pio test` (по репозиторию)
- `pre-commit run --all-files`

## 🌐 Язык

- Код и комментарии — EN/RU по контексту
- Документация — RU/EN по контексту
