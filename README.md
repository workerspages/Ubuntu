以将 `cloudflared` 程序集成到 Uptime Kuma 的 Docker 镜像中。这样，您就可以通过 Cloudflare Tunnel 将 Uptime Kuma 服务安全地暴露到公网，而无需在主机上开放端口或进行复杂的防火墙配置。

我们将基于 Uptime Kuma 的官方镜像进行修改，因为这比从一个纯净的 Ubuntu 系统开始构建更高效、更可靠。

### **实现步骤**

我们将创建一个新的 `Dockerfile` 和一个启动脚本 `start.sh`。`start.sh` 脚本将负责同时启动 Uptime Kuma 和 `cloudflared` 两个进程。

1.  **创建 `Dockerfile`**

    创建一个名为 `Dockerfile` 的文件，并将以下内容复制进去。这个文件定义了如何构建我们的自定义镜像。

```dockerfile
# 步骤 1: 使用官方 Uptime Kuma 镜像作为基础
# 这确保了 Node.js 环境和 Uptime Kuma 本身已经正确安装和配置。
FROM louislam/uptime-kuma:2

# 步骤 2: 切换到 root 用户
# 为了安装新的软件包，需要 root 权限。
USER root

# 步骤 3: 更新软件包列表并安装 cloudflared
# 我们使用 curl 下载最新的 amd64 架构的 .deb 安装包，然后用 dpkg 安装。
# 注意：如果您的服务器是 ARM 架构 (如树莓派), 请将下面的 URL 中的 "amd64" 更改为 "arm64"。
RUN apt-get update && \
    apt-get install -y curl && \
    curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb && \
    dpkg -i cloudflared.deb && \
    # 清理工作：删除下载的安装包并清理 apt 缓存，以减小镜像体积。
    rm cloudflared.deb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 步骤 4: 复制并授权启动脚本
# 将我们本地的 start.sh 脚本复制到镜像的根目录下，并赋予它执行权限。
COPY start.sh /start.sh
RUN chmod +x /start.sh

# 步骤 5: 切换回非 root 用户
# 为了安全起见，完成安装后，我们将用户切换回 Uptime Kuma 默认的 'node' 用户。
USER node

# 步骤 6: 设置容器的默认启动命令
# 指定容器启动时执行我们的自定义脚本。
CMD ["/start.sh"]
```

**注意**：上述 `curl` 命令下载的是 `amd64` (x86_64) 架构的版本。如果您在 ARM 架构（如树莓派）的机器上运行，需要将 URL 中的 `amd64` 替换为 `arm64`。

2.  **创建 `start.sh` 脚本**

    在与 `Dockerfile` 相同的目录下，创建一个名为 `start.sh` 的文件。这个脚本将启动两个服务。

```bash
#!/bin/sh

# 设置 shell 在遇到错误时立即退出
set -e

# 1. 在后台启动 Uptime Kuma 服务
# 我们使用 'node server/server.js' 命令，这是官方镜像启动服务的方式。
# '&' 符号让这个命令在后台运行，这样脚本可以继续执行下面的命令。
echo "Starting Uptime Kuma..."
node server/server.js &

# 2. 检查 TUNNEL_TOKEN 环境变量
# cloudflared 需要一个 token 才能认证并连接到 Cloudflare Tunnel。
# 这个 token 必须通过环境变量传入。
if [ -z "$TUNNEL_TOKEN" ]; then
  # 如果没有提供 token，打印错误信息并退出脚本，防止 cloudflared 启动失败。
  echo "Error: TUNNEL_TOKEN environment variable is not set." >&2
  # 等待后台的Uptime Kuma进程（虽然在这种情况下它可能是唯一的进程）
  wait
  exit 1
fi

# 3. 等待 Uptime Kuma 启动
# 给予 Uptime Kuma 几秒钟的时间来完成初始化并开始监听端口。
# 这样可以避免 cloudflared 尝试连接一个尚未就绪的服务。
echo "Waiting for Uptime Kuma to be ready..."
sleep 5

# 4. 在前台启动 cloudflared Tunnel 服务
# 这个命令会连接到 Cloudflare 并将流量转发到 Uptime Kuma 的 3001 端口。
# '--no-autoupdate' 是在容器中运行的推荐参数。
# '--url' 参数告诉 cloudflared 将外部流量转发到哪个内部地址。
# 这个命令会持续运行，作为容器的主进程，从而保持容器的存活状态。
echo "Starting Cloudflared Tunnel..."
cloudflared tunnel --no-autoupdate run --token $TUNNEL_TOKEN

```


3.  **构建 Docker 镜像**

    确保 `Dockerfile` 和 `start.sh` 文件在同一个目录下。打开终端，执行以下命令来构建您的自定义镜像：

    ```bash
    docker build -t uptime-kuma-cloudflared .
    ```
    *   `-t uptime-kuma-cloudflared`：为您的新镜像命名。

4.  **运行集成了 `cloudflared` 的容器**

    在运行容器之前，您需要先从 Cloudflare Zero Trust 仪表板获取您的 Tunnel Token。

    获取到 Token 后，使用以下命令运行容器：

    ```bash
    docker run -d \
      --restart=unless-stopped \
      -e TUNNEL_TOKEN="YOUR_TUNNEL_TOKEN_HERE" \
      -v uptime-kuma-data:/app/data \
      --name uptime-kuma-tunnel \
      uptime-kuma-cloudflared
    ```

    请替换以下参数：
    *   `YOUR_TUNNEL_TOKEN_HERE`：替换为您从 Cloudflare 获取的隧道令牌。
    *   `uptime-kuma-data`：这是用于持久化存储 Uptime Kuma 数据的 Docker 数据卷名称。
    *   `uptime-kuma-tunnel`：这是容器的名称。

### **工作原理**

*   当容器启动时，它会执行 `start.sh` 脚本。
*   脚本首先在后台启动 Uptime Kuma 的 Node.js 服务。
*   然后，脚本会启动 `cloudflared` 进程，并使用您通过环境变量传入的 `TUNNEL_TOKEN` 来连接到 Cloudflare 的边缘网络。
*   `cloudflared` 会自动将分配给您的 Tunnel 的公共域名流量，安全地转发到容器内部的 `localhost:3001`，也就是 Uptime Kuma 正在监听的地址。

通过这种方式，您成功地将 Uptime Kuma 和 `cloudflared` 打包到了一个镜像中，实现了简洁、安全的部署。
