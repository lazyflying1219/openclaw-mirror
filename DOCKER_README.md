# OpenClaw 汉化发行版 - Docker 镜像

> OpenClaw (Clawdbot/Moltbot) 中文汉化版，CLI 和 Dashboard 均已深度汉化，每小时自动同步上游官方更新。

## 快速启动

```bash
# 初始化配置
docker run --rm -v openclaw-data:/root/.openclaw \
  1186258278/openclaw-zh:latest openclaw setup

docker run --rm -v openclaw-data:/root/.openclaw \
  1186258278/openclaw-zh:latest openclaw config set gateway.mode local

# 启动容器
docker run -d --name openclaw -p 18789:18789 \
  -v openclaw-data:/root/.openclaw \
  --restart unless-stopped \
  1186258278/openclaw-zh:latest \
  openclaw gateway run
```

访问: `http://localhost:18789`

## 可用标签

| 标签 | 说明 |
|------|------|
| `latest` | 稳定版，经过测试推荐使用 |
| `nightly` | 每小时同步上游最新代码 |

## Docker Compose

```yaml
version: '3.8'
services:
  openclaw:
    image: 1186258278/openclaw-zh:latest
    container_name: openclaw
    ports:
      - "18789:18789"
    volumes:
      - openclaw-data:/root/.openclaw
    restart: unless-stopped
    command: openclaw gateway run

volumes:
  openclaw-data:
```

## 镜像地址

| 镜像源 | 地址 | 适用场景 |
|--------|------|----------|
| **Docker Hub** | `1186258278/openclaw-zh` | 国内用户推荐 |
| **ghcr.io** | `ghcr.io/1186258278/openclaw-zh` | 海外用户 |

## 相关链接

- [汉化官网](https://openclaw.qt.cool/)
- [GitHub 仓库](https://github.com/1186258278/OpenClawChineseTranslation)
- [完整 Docker 部署指南](https://github.com/1186258278/OpenClawChineseTranslation/blob/main/docs/DOCKER_GUIDE.md)
- [npm 包](https://www.npmjs.com/package/@qingchencloud/openclaw-zh)

---

**武汉晴辰天下网络科技有限公司** | [qingchencloud.com](https://qingchencloud.com/)

---

## HF Space / 临时磁盘场景：启动时自动恢复 workspace

如果运行环境不能持久化 `/root/.openclaw/workspace`（例如某些 HF Space 场景），可以把**系统镜像**和**个人 workspace**分开：

- **系统级镜像 / Docker 构建**：由本仓库 `openclaw-mirror` 负责
- **个人 workspace 备份**：由单独的备份仓库（例如 `openclaw-backup`）负责

本镜像现在支持在启动前自动尝试从备份仓库恢复 workspace。

### 需要的环境变量

```bash
OPENCLAW_BACKUP_REPO=owner/repo
OPENCLAW_BACKUP_GITHUB_TOKEN=ghp_xxx   # 私有仓库需要；公开仓库可省略
OPENCLAW_BACKUP_BRANCH=main            # 可选，默认 main
OPENCLAW_BACKUP_RESTORE_MODE=if-empty  # off | if-empty | always
OPENCLAW_BACKUP_SNAPSHOT=latest        # 可选，默认 latest
```

### 行为说明

- `if-empty`：只有在 `/root/.openclaw/workspace` 看起来还没初始化时才恢复
- `always`：每次启动都先覆盖恢复
- `off`：禁用自动恢复
- 默认会用 `manifests/<snapshot>.sha256` 做校验；如需跳过，可设置 `OPENCLAW_BACKUP_RESTORE_NO_VERIFY=1`
- 若希望恢复失败时直接让容器启动失败，可设置 `OPENCLAW_BACKUP_RESTORE_STRICT=1`

### Docker Compose 示例

```yaml
environment:
  - OPENCLAW_BACKUP_REPO=lazyflying1219/openclaw-backup
  - OPENCLAW_BACKUP_GITHUB_TOKEN=${OPENCLAW_BACKUP_GITHUB_TOKEN}
  - OPENCLAW_BACKUP_BRANCH=main
  - OPENCLAW_BACKUP_RESTORE_MODE=if-empty
```

这样做的结果是：镜像更新继续走本仓库，个人 workspace 则从备份仓库恢复，二者互不混淆。
