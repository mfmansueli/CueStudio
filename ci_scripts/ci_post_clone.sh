#!/bin/sh
set -eu

# Xcode Cloud provides Homebrew, but third-party tools must be installed after cloning.
# Keep this PATH in sync with the SwiftLint build phase; exports do not carry over to it.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

if ! command -v swiftlint >/dev/null 2>&1; then
    if ! command -v brew >/dev/null 2>&1; then
        echo "error: Homebrew was not found in PATH; cannot install SwiftLint."
        exit 1
    fi
    brew install swiftlint
fi

if ! command -v swiftlint >/dev/null 2>&1; then
    echo "error: SwiftLint was not found in PATH after installation."
    exit 1
fi

echo "SwiftLint executable: $(command -v swiftlint)"
echo "SwiftLint version:"
swiftlint version
