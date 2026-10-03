#!/bin/sh
cd -- "$(dirname -- "$0")" || exit 1
export ROLEPLAY_HOST="${ROLEPLAY_HOST:-0.0.0.0}"
exec python3 server.py
