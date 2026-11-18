#!/bin/bash
set -euo pipefail

# BYOND_MAJOR and BYOND_MINOR can be explicitly set, such as in alt_byond_versions.txt
if [ -z "${BYOND_MAJOR+x}" ]; then
  source dependencies.sh
fi

download_byond_archive() {
  curl --fail --location --silent --show-error \
    --connect-timeout 10 --max-time 45 \
    --retry 2 --retry-all-errors --retry-max-time 60 \
    --user-agent "tgstation/1.0 CI Script" \
    --output byond.zip "$1" &&
    unzip -qt byond.zip
}

if [ -d "$HOME/BYOND/byond/bin" ] && grep -Fxq "${BYOND_MAJOR}.${BYOND_MINOR}" "$HOME/BYOND/version.txt";
then
  echo "Using cached directory."
else
  echo "Setting up BYOND."
  rm -rf "$HOME/BYOND"
  mkdir -p "$HOME/BYOND"
  cd "$HOME/BYOND"
  archive_path="${BYOND_MAJOR}/${BYOND_MAJOR}.${BYOND_MINOR}_byond_linux.zip"
  if ! download_byond_archive "http://www.byond.com/download/build/$archive_path"; then
    echo "Attempting fallback mirror..."
    rm -f byond.zip
    if ! download_byond_archive "https://byond-builds.dm-lang.org/$archive_path"; then
      echo "Could not download a valid BYOND ${BYOND_MAJOR}.${BYOND_MINOR} archive from either source." >&2
      rm -f byond.zip
      exit 1
    fi
  fi
  unzip byond.zip
  rm byond.zip
  cd byond
  make here
  echo "$BYOND_MAJOR.$BYOND_MINOR" > "$HOME/BYOND/version.txt"
  cd ~/
fi
