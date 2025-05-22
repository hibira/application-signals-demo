#!/usr/bin/env bash

set -euo pipefail

# Variables
BUILDER_CONFIG="builder-config.yaml"
OCB_BINARY="ocb"
OCB_VERSION="0.111.0"
OCB_URL="https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/cmd%2Fbuilder%2Fv${OCB_VERSION}/ocb_${OCB_VERSION}_linux_amd64"

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Ensure required commands are available
for cmd in wget chmod; do
    if ! command_exists "$cmd"; then
        echo "Error: Required command '$cmd' is not installed."
        exit 1
    fi
done

# Ensure the script is running in the correct directory
if [[ ! -f "${BUILDER_CONFIG}" ]]; then
    echo "Error: ${BUILDER_CONFIG} not found in $(pwd)"
    exit 1
fi

# Download and verify the OCB binary if not present
if [[ ! -f "${OCB_BINARY}" ]] || [[ ! -x "${OCB_BINARY}" ]]; then
    echo "Downloading OpenTelemetry Collector Builder..."
    
    # Remove existing binary if it exists but isn't executable
    rm -f "${OCB_BINARY}"
    
    # Download the binary
    if ! wget -q "${OCB_URL}" -O "${OCB_BINARY}"; then
        echo "Error: Failed to download OCB binary from ${OCB_URL}"
        exit 1
    fi
    
    # Make the binary executable
    if ! chmod +x "${OCB_BINARY}"; then
        echo "Error: Failed to make OCB binary executable"
        exit 1
    fi
    
    # Verify the binary is executable
    if [[ ! -x "${OCB_BINARY}" ]]; then
        echo "Error: OCB binary exists but is not executable"
        exit 1
    fi
fi

# Create output directory if it doesn't exist
mkdir -p otelcol-dev

# Build the collector
echo "Building OpenTelemetry Collector..."
if ! ./"${OCB_BINARY}" --config "${BUILDER_CONFIG}"; then
    echo "Error: Failed to build the collector"
    exit 1
fi

# Verify the build output exists
if [[ ! -f "otelcol-dev/otelcol-dev" ]]; then
    echo "Error: Build completed but otelcol-dev binary not found"
    exit 1
fi

# Make the output binary executable
chmod +x otelcol-dev/otelcol-dev

echo "Collector built successfully. Binary is at otelcol-dev/otelcol-dev"
