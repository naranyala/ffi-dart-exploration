#!/bin/sh

TARGET="nob.h"
BACKUP="${TARGET}.backup"
URL="https://raw.githubusercontent.com/tsoding/nob.h/main/nob.h"

# Function to extract version from nob.h
extract_version() {
    grep -m1 'nob - v' "$1" | sed -E 's|/\* nob - (v[0-9]+\.[0-9]+\.[0-9]+).*|\1|'
}

# If nob.h exists, extract and display version before backup
if [ -f "$TARGET" ]; then
    OLD_VERSION=$(extract_version "$TARGET")
    echo "Existing $TARGET found (version: ${OLD_VERSION:-unknown}). Backing it up to $BACKUP..."
    mv "$TARGET" "$BACKUP"
fi

# Download the latest nob.h
echo "Downloading latest $TARGET from $URL..."
wget -O "$TARGET" "$URL"

# Extract and display new version
if [ $? -eq 0 ]; then
    NEW_VERSION=$(extract_version "$TARGET")
    echo "$TARGET successfully downloaded (version: ${NEW_VERSION:-unknown})."
else
    echo "Download failed. Please check your connection or the URL."
fi


