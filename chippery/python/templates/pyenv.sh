#!/usr/bin/env bash

export PYENV_ROOT="/usr/local/pyenv"

if [[ ":$PATH:" != *":$PYENV_ROOT/bin:"* ]]; then
    export PATH="$PYENV_ROOT/bin:$PATH"
fi
exec "$PYENV_ROOT/bin/pyenv" "$@"
