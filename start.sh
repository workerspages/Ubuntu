#!/bin/sh

# 设置 shell 在遇到错误时立即退出
set -e

# ==============================================================================
# !!! 安全警告: 将 Token 硬编码在此处会带来严重的安全风险 !!!
# !!! 任何能够访问此 Docker 镜像的人都可以轻易地提取出这个 Token !!!
# !!! 强烈建议使用环境变量来传递 Token !!!
#
# 在下面的引号中粘贴你的真实隧道令牌
TUNNEL_TOKEN="<在这里粘贴你的隧道令牌>"
# ==============================================================================


# 1. 在后台启动 Uptime Kuma 服务
echo "Starting Uptime Kuma..."
node server/server.js &

# 2. 检查 Token 是否已被替换
if [ "$TUNNEL_TOKEN" = "<在这里粘贴你的隧道令牌>" ] || [ -z "$TUNNEL_TOKEN" ]; then
  # 如果用户没有替换占位符，打印错误信息并退出。
  echo "错误：请务必编辑 start.sh 文件，将占位符 '<在这里粘贴你的隧道令牌>' 替换为你的真实隧道令牌。" >&2
  # 等待后台进程结束
  wait
  exit 1
fi

# 3. 等待 Uptime Kuma 启动
echo "Waiting for Uptime Kuma to be ready..."
sleep 5

# 4. 在前台启动 cloudflared Tunnel 服务
# 脚本将使用上面定义的 TUNNEL_TOKEN 变量
echo "Starting Cloudflared Tunnel..."
cloudflared tunnel --no-autoupdate run --token $TUNNEL_TOKEN
