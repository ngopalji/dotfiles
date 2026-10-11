#!/bin/bash

CONFIG_FILE="$HOME/.config/ghostty/config"

if [[ -z "$1" ]]; then
    echo "Usage: set-theme.sh <theme-name>"
    echo "Example: set-theme.sh 'GitHub Dark Default'"
    exit 1
fi

THEME="$1"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Config file not found at $CONFIG_FILE"
    exit 1
fi

# Check if an uncommented theme line exists
if grep -q "^theme = " "$CONFIG_FILE"; then
    # Replace existing theme line
    sed -i '' "s/^theme = .*/theme = $THEME/" "$CONFIG_FILE"
    echo "Theme updated to: $THEME"
else
    # No theme line found, append one
    echo "theme = $THEME" >> "$CONFIG_FILE"
    echo "Theme added: $THEME"
fi
