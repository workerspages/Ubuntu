# 步骤 1: 使用官方 Uptime Kuma 镜像作为基础
FROM louislam/uptime-kuma:2

# 步骤 2: 切换到 root 用户以安装所有依赖项
USER root

# 设置环境变量，防止安装过程中出现交互式提示
ENV DEBIAN_FRONTEND=noninteractive

# 步骤 3: 安装系统基础依赖和 Python 环境
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    wget unzip curl gnupg msmtp \
    python3 python3-pip \
    fonts-wqy-zenhei fonts-wqy-microhei \
    libglib2.0-0 libnss3 libgconf-2-4 libfontconfig1

# 步骤 4: 安装 Google Chrome 浏览器
RUN wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome-keyring.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome-keyring.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list && \
    apt-get update && \
    apt-get install -y google-chrome-stable --no-install-recommends

# 步骤 5: 安装与 Chrome 版本匹配的 ChromeDriver
RUN CHROME_VERSION=$(google-chrome --version | cut -d " " -f3 | cut -d "." -f1-3) && \
    DRIVER_VERSION=$(curl -s "https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json" | python3 -c "import sys, json; print(next(v['version'] for v in reversed(json.load(sys.stdin)['versions']) if v['version'].startswith('$CHROME_VERSION')))") && \
    wget -q "https://storage.googleapis.com/chrome-for-testing-public/${DRIVER_VERSION}/linux64/chromedriver-linux64.zip" -O chromedriver.zip && \
    unzip chromedriver.zip && \
    mv chromedriver-linux64/chromedriver /usr/bin/chromedriver && \
    chown root:root /usr/bin/chromedriver && \
    chmod +x /usr/bin/chromedriver && \
    rm chromedriver.zip && rm -rf chromedriver-linux64

# 步骤 6: 安装 cloudflared
RUN curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb && \
    dpkg -i cloudflared.deb && \
    rm cloudflared.deb

# 步骤 7: 使用 pip 安装 Python 库 (!!! 这里是关键的修复 !!!)
RUN pip3 install \
    --no-cache-dir \
    --break-system-packages \
    requests \
    selenium \
    Pillow

# 步骤 8: 清理工作，减小镜像体积
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 复制启动脚本并赋予执行权限
COPY start.sh /start.sh
RUN chmod +x /start.sh

# 切换回非 root 的 node 用户，以增强安全性
USER node

# 设置容器的默认启动命令
CMD ["/start.sh"]
