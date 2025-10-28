#!/bin/sh

# 设置 shell 在遇到错误时立即退出
set -e

# 1. 在后台启动 Uptime Kuma 服务
echo "Starting Uptime Kuma..."
node server/server.js &

# 2. 检查 TUNNEL_TOKEN 环境变量
if [ -z "$TUNNEL_TOKEN" ]; then
  echo "Warning: TUNNEL_TOKEN is not set. Cloudflared will not start." >&2
  # 如果没有 token, 只让 Uptime Kuma 保持运行
  wait
  exit 0
fi

# 3. 等待 Uptime Kuma 启动
echo "Waiting for Uptime Kuma to be ready..."
sleep 5

# 4. 在前台启动 cloudflared Tunnel 服务
echo "Starting Cloudflared Tunnel..."
cloudflared tunnel --no-autoupdate run --token $TUNNEL_TOKEN
