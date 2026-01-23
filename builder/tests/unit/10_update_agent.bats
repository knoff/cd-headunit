#!/usr/bin/env bats

@test "System Unit Tests: Python Agent" {
    # Ensure /workspace/system is reachable.
    # Current dir in container is usually /workspace.

    run python3 -m unittest discover -s /workspace/system/tests/unit -p "test_*.py"

    if [ "$status" -ne 0 ]; then
        echo "Python Unit Tests Failed:"
        echo "$output"
    fi

    [ "$status" -eq 0 ]
}
