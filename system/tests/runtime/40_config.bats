#!/usr/bin/env bats

load "test_helper"

@test "Config: Library 'hu_config' is importable" {
    # Пытаемся импортировать библиотеку внутри Python
    # Если импорт упадет (SyntaxError или файл не найден), тест провалится
    run python3 -c "import hu_config; print('OK')"
    [ "$status" -eq 0 ]
    [ "$output" = "OK" ]
}

@test "Config: Factory defaults are present" {
    [ -f "/etc/headunit/factory_defaults.json" ]
}

@test "Config [WARN]: User settings file exists (Device Provisioned)" {
    # Если файла настроек нет, это не ошибка (чистая машина), но Warning
    if [ ! -f "/data/configs/user_settings.json" ]; then
        skip "WARN: Device not provisioned (User config missing)"
    fi
    [ -f "/data/configs/user_settings.json" ]
}

@test "Config [WARN]: Identity is configured (Hostname check)" {
    run cat /etc/hostname

    # Если hostname стандартный — машина еще не настроена
    if [[ "$output" == "raspberrypi" ]] || [[ "$output" == "headunit-generic" ]] || [[ "$output" == "CDR-00000000" ]]; then
         skip "WARN: Hostname is generic (Identity not set)"
    fi

    # Ожидаем формат cdreborn-XXXX
    [[ "$output" == *"cdr"* ]]
}
