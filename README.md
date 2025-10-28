以将 `cloudflared` 程序集成到 Uptime Kuma 的 Docker 镜像中。这样，您就可以通过 Cloudflare Tunnel 将 Uptime Kuma 服务安全地暴露到公网，而无需在主机上开放端口或进行复杂的防火墙配置。

我们将基于 Uptime Kuma 的官方镜像进行修改，因为这比从一个纯净的 Ubuntu 系统开始构建更高效、更可靠。

### **实现步骤**

我们将创建一个新的 `Dockerfile` 和一个启动脚本 `start.sh`。`start.sh` 脚本将负责同时启动 Uptime Kuma 和 `cloudflared` 两个进程。

1.  **创建 `Dockerfile`**

    创建一个名为 `Dockerfile` 的文件，并将以下内容复制进去。这个文件定义了如何构建我们的自定义镜像。

    ```dockerfile
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
    ```
    *   **注意**：上述 `curl` 命令下载的是 `amd64` (x86_64) 架构的版本。如果您在 ARM 架构（如树莓派）的机器上运行，需要将 URL 中的 `amd64` 替换为 `arm64`。

2.  **创建 `start.sh` 脚本**

    在与 `Dockerfile` 相同的目录下，创建一个名为 `start.sh` 的文件。这个脚本将启动两个服务。

    ```bash
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
