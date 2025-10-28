好的，您可以将 `TUNNEL_TOKEN`直接集成到 `start.sh` 脚本文件中。这样，在构建镜像时，这个令牌就会被永久地写入镜像里。

但是，在您这样做之前，请务必阅读下面的 **重要安全警告**。

---

### **修改后的 `start.sh` 文件**

您只需要修改 `start.sh` 文件。`Dockerfile` 的内容保持不变。

```bash
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
```

### **`Dockerfile` (保持不变)**

`Dockerfile` 不需要任何改动，它会按原样复制上面修改过的 `start.sh` 文件。

```dockerfile
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
```

---

### **重要安全警告：为什么不应该这样做**

尽管技术上可行，但将密钥（如 `TUNNEL_TOKEN`）直接硬编码到 Docker 镜像中是一种**非常危险**的做法，原因如下：

1.  **严重的安全风险**：任何能够访问这个 Docker 镜像文件的人（无论是通过 `docker save` 导出，还是从 Docker 仓库拉取），都可以通过 `docker history` 或其他工具轻松地查看到镜像层中的 `start.sh` 文件，从而**窃取您的 `TUNNEL_TOKEN`**。这会使您的 Cloudflare Tunnel 和其背后的服务完全暴露。

2.  **缺乏灵活性**：如果您的 Token 因为任何原因需要更换（例如，重建了隧道），您将必须**重新编辑 `start.sh` 文件、重新构建整个 Docker 镜像、然后重新部署容器**。这个过程非常繁琐。

3.  **违反了最佳实践**：容器化应用的最佳实践（如 [The Twelve-Factor App](https://12factor.net/config)）明确指出，配置（尤其是密钥）应该与代码分离，并通过环境变量注入。

### **推荐的、更安全的方法（回顾）**

我们之前的做法是正确且安全的。通过环境变量传递 `TUNNEL_TOKEN`，您可以：
*   保持镜像的通用性和安全性，镜像本身不包含任何敏感信息。
*   在运行时轻松更换 Token，只需修改 `docker run` 命令中的环境变量即可，无需重新构建镜像。

**安全的运行命令示例：**
```bash
docker run -d \
  --restart=unless-stopped \
  -e TUNNEL_TOKEN="你的真实隧道令牌" \
  -v uptime-kuma-data:/app/data \
  --name uptime-kuma-tunnel \
  uptime-kuma-cloudflared
```

**总结：请坚持使用环境变量的方式来传递 `TUNNEL_TOKEN`，以确保您的服务安全和部署的灵活性。**
