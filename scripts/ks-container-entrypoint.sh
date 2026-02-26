#!/bin/bash
set -e

# Create user with matching UID/GID if it doesn't exist
if ! id -u sandboxuser &>/dev/null; then
  groupadd -g "${SANDBOX_GID:-1000}" sandboxuser 2>/dev/null || true
  useradd -u "${SANDBOX_UID:-1000}" -g "${SANDBOX_GID:-1000}" -M -s /bin/bash sandboxuser 2>/dev/null || true

  # Create home directory if it doesn't exist
  mkdir -p /home/sandboxuser

  # Create minimal shell config files
  touch /home/sandboxuser/.bashrc /home/sandboxuser/.profile
  echo 'export PATH="$HOME/.local/bin:$PATH"' >>/home/sandboxuser/.bashrc

  # Ensure correct ownership
  chown -R sandboxuser:sandboxuser /home/sandboxuser 2>/dev/null || true
fi

# Execute kiro-cli as sandboxuser
exec gosu sandboxuser "$@"
