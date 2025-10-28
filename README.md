好的，我们可以将所有这些组件——包括系统包、Python 环境、Google Chrome、ChromeDriver 和其他工具——都集成到 Uptime Kuma 的 Docker 镜像中。

这将创建一个功能非常强大的“一体化”镜像，但请注意，它的体积会变得**非常大**（可能会达到 2-3 GB 或更多），并且构建过程会比较慢。

下面是完整的 `Dockerfile` 和配套的 `start.sh` 以及推荐的 `docker-compose.yml` 文件。

---

### **`Dockerfile`**

这个 `Dockerfile` 会执行以下所有操作：
1.  基于官方 Uptime Kuma 镜像。
2.  安装所有请求的系统软件包（`wget`, `unzip`, `msmtp`, 中文字体等）。
3.  安装 Python 3 和 Pip。
4.  添加 Google Chrome 的官方软件源并安装浏览器。
5.  下载并安装与该版本 Chrome 兼容的 ChromeDriver。
6.  安装 `cloudflared`。
7.  使用 Pip 安装所有请求的 Python 库。

```dockerfile
# 步骤 1: 使用官方 Uptime Kuma 镜像作为基础
FROM louislam/uptime-kuma:2

# 步骤 2: 切换到 root 用户以安装所有依赖项
USER root

# 设置环境变量，防止安装过程中出现交互式提示
ENV DEBIAN_FRONTEND=noninteractive

# 步骤 3: 安装所有系统依赖项和 Python
# 一次性运行所有 apt-get 命令以减少镜像层数
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    # 系统工具
    wget \
    unzip \
    curl \
    gnupg \
    msmtp \
    # Python 环境
    python3 \
    python3-pip \
    # 中文字体，用于 Selenium 截图
    fonts-wqy-zenhei \
    fonts-wqy-microhei \
    # 安装 Google Chrome 所需的库
    libglib2.0-0 \
    libnss3 \
    libgconf-2-4 \
    libfontconfig1 && \
    
    # 步骤 4: 安装 Google Chrome 浏览器
    # 添加 Google 的官方 GPG 密钥
    wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome-keyring.gpg && \
    # 添加 Chrome 的软件源
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome-keyring.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list && \
    # 再次更新软件源列表并安装 Chrome
    apt-get update && \
    apt-get install -y google-chrome-stable --no-install-recommends && \

    # 步骤 5: 安装与 Chrome 版本匹配的 ChromeDriver
    # 注意：这个过程可能因 Chrome 更新而需要调整
    # 获取已安装的 Chrome 版本号
    CHROME_VERSION=$(google-chrome --version | cut -d " " -f3 | cut -d "." -f1-3) && \
    # 从新的 JSON API 获取对应的 ChromeDriver 版本
    DRIVER_VERSION=$(curl -s "https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json" | python3 -c "import sys, json; print(next(v['version'] for v in reversed(json.load(sys.stdin)['versions']) if v['version'].startswith('$CHROME_VERSION')))") && \
    wget -q "https://storage.googleapis.com/chrome-for-testing-public/${DRIVER_VERSION}/linux64/chromedriver-linux64.zip" -O chromedriver.zip && \
    unzip chromedriver.zip && \
    mv chromedriver-linux64/chromedriver /usr/bin/chromedriver && \
    chown root:root /usr/bin/chromedriver && \
    chmod +x /usr/bin/chromedriver && \
    rm chromedriver.zip && rm -rf chromedriver-linux64 && \

    # 步骤 6: 安装 cloudflared
    curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb && \
    dpkg -i cloudflared.deb && \
    rm cloudflared.deb && \

    # 步骤 7: 使用 pip 安装 Python 库
    # --no-cache-dir 选项可以减小镜像体积
    pip3 install --no-cache-dir \
    requests \
    selenium \
    Pillow && \

    # 步骤 8: 清理工作
    # 删除所有 apt 缓存和不必要的文件，以尽可能减小最终镜像的体积
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 复制启动脚本并赋予执行权限
COPY start.sh /start.sh
RUN chmod +x /start.sh

# 切换回非 root 的 node 用户，以增强安全性
USER node

# 设置容器的默认启动命令
CMD ["/start.sh"]
```

---

### **`start.sh`**

这个脚本保持不变，它负责启动 Uptime Kuma 和 `cloudflared`。

```bash
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
```

---

### **`docker-compose.yml` (推荐的运行方式)**

使用 Docker Compose 是管理这个复杂镜像的最佳方式。

```yaml
version: '3.8'

services:
  uptime-kuma-suite:
    # 从当前目录的 Dockerfile 构建镜像
    build: .
    # 为构建好的镜像命名
    image: my-ultimate-uptime-kuma
    # 容器名称
    container_name: uptime-kuma-suite
    # 集成重启策略
    restart: unless-stopped
    # 持久化 Uptime Kuma 的数据
    volumes:
      - uptime-kuma-data:/app/data
    # 通过 .env 文件安全地传入隧道令牌
    environment:
      - TUNNEL_TOKEN=${TUNNEL_TOKEN}
    # [重要] 运行 Selenium/Chrome 需要的额外参数
    # 增加共享内存大小，防止 Chrome 崩溃
    shm_size: '2gb'
    # 添加必要的 Linux capabilities，这在某些环境下是运行 Chrome 所需的
    cap_add:
      - SYS_ADMIN

volumes:
  uptime-kuma-data:
```

### **`.env` 文件**

在 `docker-compose.yml` 旁边创建一个 `.env` 文件来存放你的密钥。

```
TUNNEL_TOKEN=<在这里粘贴你的隧道令牌>
```

### **如何使用**

1.  将 `Dockerfile`, `start.sh`, `docker-compose.yml`, 和 `.env` 这四个文件放在同一个文件夹中。
2.  在 `.env` 文件中填入你自己的 Cloudflare Tunnel Token。
3.  打开终端，进入该文件夹。
4.  运行构建和启动命令：
    ```bash
    docker-compose up --build -d
    ```
    *   `--build` 会强制根据 `Dockerfile` 重新构建镜像。
    *   `-d` 会让容器在后台运行。

现在，您就有了一个包含所有指定工具的、功能完备的 Uptime Kuma 容器了。
