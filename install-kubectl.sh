#!/bin/bash

#
# Installs "kubectl"
#

set -euo pipefail

# Find a suitable install location
for CANDIDATE in "$HOME/bin" "/usr/local/bin" "/usr/bin"; do
  if [[ -w $CANDIDATE ]] && grep -q "$CANDIDATE" <<<"$PATH"; then
    TARGET_DIR="$CANDIDATE"
    break
  fi
done

# Bail out in case no suitable location could be found
if [[ -z ${TARGET_DIR:-} ]]; then
  echo -e "Unable to determine a writable install location. Make sure that you have write access to either \\033[1m/usr/local/bin\\033[0m or \\033[1m${HOME}/bin\\033[0m and that is in your PATH."
  exit 1
fi

# Look-up current stable version from their release site
STABLE_VERSION="$(curl --fail --silent --location https://dl.k8s.io/release/stable.txt)"

# Determine the architecture
ARCH=$(uname -m | sed -e 's/x86_64/amd64/' -e 's/aarch64/arm64/')

echo "# Downloading kubectl binary..."
curl --fail --progress-bar --location "https://dl.k8s.io/release/${STABLE_VERSION}/bin/linux/${ARCH}/kubectl" --output "${TARGET_DIR}/kubectl"
chmod a+rx "${TARGET_DIR}/kubectl"

echo "# Validating kubectl binary..."
sha256sum --check <<<"$(curl --fail --silent --location "https://dl.k8s.io/${STABLE_VERSION}/bin/linux/${ARCH}/kubectl.sha256") ${TARGET_DIR}/kubectl"

echo "# Kubectl version"
kubectl version --client
