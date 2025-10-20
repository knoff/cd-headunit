<!-- markdownlint-configure-file {"MD041": false} -->

## [2025-10-13 16:44 GMT+3]

### docs: Create README.md

Создан базовый `README.md` с названием репозитория `cd-headunit`.

## [2025-10-13 16:51 GMT+3]

### chore: blank gitignore

Добавлен начальный `.gitignore` с шаблоном исключений для Python, Docker, Ansible и IDE.

## [2025-10-16 13:34 GMT+3]

### chore: workspace setup, formatting & linting, gitignore

Настроено базовое окружение проекта.
Добавлены файлы: `.editorconfig`, `.gitattributes`, `.gitignore`, `.pre-commit-config.yaml`, `.markdownlint.json`, `.prettierrc.json`, `.yamllint.yaml`.
Настроен GitHub Actions workflow `lint.yml` для автоматической проверки форматирования.
Обеспечена совместимость линтинга и форматирования на Python, JS/TS и Markdown.

## [2025-10-16 15:52 GMT+3]

### chore: directory structure

Создана структура директорий проекта.
Выделены каталоги `docs/`, `src/`, `lib/`, `deploy/`, `tests/` и `app/` (при необходимости).
Подготовлен каркас для дальнейшей интеграции сервисов MQTT, OTA и UI.

## [2025-10-16 16:47 GMT+3]

### docs: Определение структуры документации

Созданы базовые файлы документации:
`README.md`, `CONTRIBUTING.md`, `docs/architecture.md`, `docs/README.md`.
Определена структура проекта, формат коммитов, ветвление (`main`, `develop`, `feature/*`), правила участия и линтинга.
Добавлено описание архитектуры Headunit и его взаимодействия с другими компонентами.

## [2025-10-20 14:53 GMT+3]

### docs(repo_instructions): AI workflow and repo_notes

Добавлены файлы `.repo_instructions/WORKFLOW.md` и `repo_notes.md`.
Определён цикл сессий (инициализация, рабочий этап, завершение), структура логов (`COMMITS.md`, `SESSIONS.md`) и правила фиксации инженерных решений.
Внесены шаблоны (`commit_template.md`, `session_log_template.md`, `task_comment_template.md`, `detour_template.md`).
Уточнены роли и поведение ассистента в диалоге.
