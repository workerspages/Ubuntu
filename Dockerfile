# 使用官方 Uptime Kuma 镜像作为基础
FROM louislam/uptime-kuma:2

# 切换到 root 用户
USER root

# 安装 cloudflared
RUN apt-get update && \
    apt-get install -y curl && \
    curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb && \
    dpkg -i cloudflared.deb && \
    rm cloudflared.deb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 复制并授权启动脚本
COPY start.sh /start.sh
RUN chmod +x /start.sh

# 切换回非 root 用户
USER node

# 设置容器的默认启动命令
CMD ["/start.sh"]
