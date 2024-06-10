#!/bin/bash

git fetch origin develop:develop

# Previous version from version.properties (assuming format is version=1.2.3)
PREVIOUS_VERSION=$(git show origin/develop:version.properties | grep 'version=' | cut -d'=' -f2)

# Current version from version.properties
CURRENT_VERSION=$(cat version.properties | grep 'version=' | cut -d'=' -f2)

# Check version bump
if [[ "$PREVIOUS_VERSION" == "$CURRENT_VERSION" ]]; then
  echo "Error: The version in version.properties has not been bumped. Current version is still $CURRENT_VERSION."
  exit 1
fi

# Check for CHANGELOG.md entry
if ! grep -q "$CURRENT_VERSION" CHANGELOG.md; then
  echo "Error: No entry for version $CURRENT_VERSION found in CHANGELOG.md"
  exit 1
fi

echo "Version and CHANGELOG checks passed."
exit 0
