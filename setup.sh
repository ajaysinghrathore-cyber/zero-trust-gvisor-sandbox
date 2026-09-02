#!/usr/bin/env bash
# ==============================================================================
# Zero-Trust Container Isolation Sandbox (Docker + gVisor) Master Setup Script
# Developed for Ubuntu 24.04 LTS / WSL2
# ==============================================================================

set -e

echo "🚀 [1/6] Purging broken/corrupted Docker & WSL network states..."
sudo systemctl stop docker 2>/dev/null || true
sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null || true
sudo rm -rf /etc/apt/keyrings/docker.* /etc/apt/sources.list.d/docker.list /etc/docker/daemon.json

echo "🌐 [2/6] Restoring WSL2 Network & Systemd Configuration..."
sudo rm -f /etc/wsl.conf
cat <<'EOF' | sudo tee /etc/wsl.conf > /dev/null
[boot]
systemd=true
[network]
generateResolvConf = true
EOF

echo "🔒 [3/6] Configuring Kernel Namespaces & Network Forwarding..."
cat <<'EOF' | sudo tee -a /etc/sysctl.conf > /dev/null
user.max_user_namespaces=15000
net.ipv4.ip_forward=1
EOF
sudo sysctl -p 2>/dev/null || true

echo "🔑 [4/6] Installing Official Docker GPG Keyring (ASCII Armored)..."
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu noble stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "📦 [5/6] Installing Docker Engine & gVisor (runsc) Sandbox..."
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Download and setup latest runsc binary
URL="https://storage.googleapis.com/gvisor/releases/release/latest/x86_64"
curl -fsSL "${URL}/runsc" -o runsc
curl -fsSL "${URL}/runsc.sha512" -o runsc.sha512
sha512sum -c runsc.sha512
chmod +x runsc
sudo mv runsc /usr/local/bin/

echo "⚙️ [6/6] Registering gVisor Runtime in Docker Daemon..."
cat <<'EOF' | sudo tee /etc/docker/daemon.json > /dev/null
{
  "default-runtime": "runc",
  "runtimes": {
    "runsc": {
      "path": "/usr/local/bin/runsc",
      "runtimeArgs": [
        "--network=sandbox"
      ]
    }
  }
}
EOF

echo "✅ Master Deployment Completed Successfully!"
echo "📌 NOTE: Please run 'wsl --shutdown' in PowerShell, then restart Ubuntu terminal."
