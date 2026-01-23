#!/usr/bin/env bats

load "test_helper"

@test "Shared Libs: FastAPI is importable" {
    run python3 -c "import fastapi; print(fastapi.__version__)"
    [ "$status" -eq 0 ]
}

@test "Shared Libs: Pydantic is importable" {
    run python3 -c "import pydantic; print(pydantic.VERSION)"
    [ "$status" -eq 0 ]
}

@test "Shared Libs: Uvicorn is importable" {
    run python3 -c "import uvicorn; print(uvicorn.__version__)"
    [ "$status" -eq 0 ]
}
