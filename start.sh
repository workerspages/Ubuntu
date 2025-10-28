#!/bin/sh

set -e

# --- 新增: 启动 cron 服务 ---
# 以 root 身份启动 cron 守护进程，它会自动读取 /etc/cron.d/ 里的配置
echo "Starting cron daemon..."
sudo cron

# 1. 在后台启动 Uptime Kuma 服务
echo "Starting Uptime Kuma..."
node server/server.js &

# 2. 检查 TUNNEL_TOKEN 环境变量
if [ -z "$TUNNEL_TOKEN" ]; then
  echo "Warning: TUNNEL_TOKEN is not set. Cloudflared will not start." >&2
  wait
  exit 0
fi

# 3. 等待 Uptime Kuma 启动
echo "Waiting for Uptime Kuma to be ready..."
sleep 5

# 4. 在前台启动 cloudflared Tunnel 服务
echo "Starting Cloudflared Tunnel..."
cloudflared tunnel --no-autoupdate run --token $TUNNEL_TOKEN
