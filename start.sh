#!/bin/sh

# 启动 Uptime Kuma 进程（在后台运行）
node server/server.js &

# 检查是否提供了 TUNNEL_TOKEN 环境变量
if [ -z "$TUNNEL_TOKEN" ]; then
  echo "错误：请设置 TUNNEL_TOKEN 环境变量。"
  # 如果没有 token，只保持 Uptime Kuma 运行
  wait
  exit 1
fi

# 等待几秒钟，确保 Uptime Kuma 服务已经启动并监听端口
sleep 5

# 启动 cloudflared tunnel
# 它将会连接到 Cloudflare，并将流量转发到本地的 3001 端口
cloudflared tunnel --no-autoupdate run --token $TUNNEL_TOKEN
