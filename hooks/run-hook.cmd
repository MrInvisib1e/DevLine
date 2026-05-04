@echo off & bash -c "exec bash %~f0 %*" & exit /b
#!/usr/bin/env bash
# Polyglot bash/cmd hook runner (works on both Windows CMD and Unix bash)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "${SCRIPT_DIR}/$1"
