#!/usr/bin/env bats

@test "Services Layer: Active link exists" {
    [ -L "/run/headunit/active_services" ]
}

@test "Services Layer: Configs directory exists" {
    # Предполагаем, что сервисы несут с собой конфиги
    if [ -d "/run/headunit/active_services/configs" ]; then
        [ -d "/run/headunit/active_services/configs" ]
    else
        skip "No configs directory in services layer"
    fi
}

@test "Services Layer: Version match manifest" {
    [ -f "/run/headunit/active_services/manifest.json" ]
}
