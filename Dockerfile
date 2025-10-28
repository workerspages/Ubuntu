# 使用官方的 Uptime Kuma 镜像作为基础
FROM louislam/uptime-kuma:2

# 切换到 root 用户以安装新软件
USER root

# 安装 cloudflared
# 从 Cloudflare 的官方发布页面下载 amd64/x86_64 架构的 .deb 安装包
RUN apt-get update && \
    apt-get install -y curl && \
    curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb && \
    dpkg -i cloudflared.deb && \
    rm cloudflared.deb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 复制启动脚本到镜像中
COPY start.sh /start.sh
RUN chmod +x /start.sh

# 将用户切换回非 root 用户
USER node

# 设置启动命令为我们的自定义脚本
CMD ["/start.sh"]
