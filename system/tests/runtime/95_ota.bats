#!/usr/bin/env bats

load "test_helper"

teardown() {
    rm -rf "/tmp/ota_test_pkg"
    rm -f "/tmp/headunit-app-v0.0.0.tar.gz"
    rm -f "/tmp/headunit-app-v0.0.0.tar.gz.sha256"
    # Clean verification dir
    rm -rf "/data/components/app/0.0.0"
}

@test "OTA Agent: CLI Help Check" {
    run headunit-update-agent --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "HeadUnit Update Agent" ]]
}

@test "OTA Agent: Simulate Update Install" {
    # 1. Prepare Dummy Update Package
    TMP_DIR="/tmp/ota_test_pkg"
    mkdir -p "$TMP_DIR/v0.0.0"

    # Create manifest
    echo '{"component":"app","version":"0.0.0","dependencies":{"services":">=0.0.0"}}' > "$TMP_DIR/v0.0.0/manifest.json"
    echo "DUMMY FILE" > "$TMP_DIR/v0.0.0/dummy.txt"

    # Create tar
    TAR_PATH="/tmp/headunit-app-v0.0.0.tar.gz"
    tar -czf "$TAR_PATH" -C "$TMP_DIR" .

    # Calc SHA256 matches the agent's expectation
    sha256sum "$TAR_PATH" > "$TAR_PATH.sha256"

    # 2. Run Agent (No Reboot!)
    # We use --no-reboot to avoid killing the test runner
    run headunit-update-agent --file "$TAR_PATH" --no-reboot
    [ "$status" -eq 0 ]

    # 3. Verify Install
    INSTALL_DIR="/data/components/app/0.0.0"
    [ -d "$INSTALL_DIR" ]
    [ -f "$INSTALL_DIR/v0.0.0/manifest.json" ] || [ -f "$INSTALL_DIR/manifest.json" ]
}

@test "OTA Services: Update Monitor Path is Active" {
    run systemctl is-active headunit-update-monitor.path
    [ "$status" -eq 0 ]
}

@test "OTA Services: USB Scan Service is Loaded" {
    # It is triggered by udev, so it might be 'static' or 'enabled' depending on config,
    # but primarily we check it is loaded by systemd.
    run systemctl list-unit-files headunit-update-usb-scan.service
    [ "$status" -eq 0 ]
}
