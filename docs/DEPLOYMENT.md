# Server Edge 部署指南

本文只说明 Server Edge 的部署过程：如何把同一个公开 Release 部署到不同 Linux 主机，并让每台主机使用自己的实例配置和 Secret。

配置模型见 `CONFIGURATION.md`，宿主要求见 `HOST-CONTRACT.md`。

## 1. 部署模型

Server Edge 把软件、实例配置和 Secret 分开：

```text
Public server-edge
代码 / defaults / installer
          │
          ▼
Private control plane（可选）
每台主机自己的配置与 Secret
          │
          ▼
Target Linux Host
/opt/server-edge/
├── releases/   Release 代码与默认值
├── config/     本机非敏感实例配置
├── secrets/    本机 Secret
├── state/      持久状态
└── runtime/    运行状态与契约
```

公开仓库决定“软件是什么”；目标主机本地 `/opt/server-edge/` 决定“这台机器怎么运行”。

Server Edge 本身不访问私密 GitHub 仓库，也不读取 GitHub Environment。外部控制面只需要在目标主机准备一个临时 `instance-source`，随后调用公开 bootstrap。

## 2. 部署前提

目标主机必须满足 `HOST-CONTRACT.md`。当前部署路径至少要求：

- Linux；
- 可以通过 SSH 到达目标主机；
- SSH 用户可以执行 `sudo -n true`；
- 主机具备 `curl` 和 `tar`；
- 主机可以访问公开 GitHub；
- 生产或长期运行部署使用固定 Tag、Release 或 Commit SHA。

使用 GitHub-hosted Runner 部署时，目标主机还必须能够从 GitHub Runner 直接通过 SSH 到达。仅 Tailnet 可达的主机当前不属于这条部署路径。

## 3. 路径 A：直接部署公开 Release

如果不需要预置实例参数，可以直接安装：

```bash
curl -fsSL \
  https://raw.githubusercontent.com/fongap/server-edge/<REF>/install/bootstrap.sh \
  | sudo bash -s -- \
      --repo fongap/server-edge \
      --ref <REF>
```

默认根目录：

```text
/opt/server-edge
```

可以通过 `--root` 修改根目录，也可以通过 `--profile` 选择模块组合。

不要在长期运行环境中把 `<REF>` 写成 `main` 或 `latest`。

## 4. 路径 B：从目标主机本地实例源部署

目标主机可以先准备：

```text
<instance-source>/
├── config/
│   ├── infra.env
│   ├── proxy-hub.env
│   └── publications.json
└── secrets/
    └── <module>/...
```

`config/` 只允许平面的 `*.env` 和 `publications.json`。Secret 可以按模块建立子目录。

实例 `.env` 只写覆盖项。例如公开 Release 已经默认：

```text
SERVER_EDGE_PROXY_EGRESS_PORT=7890
```

某台主机需要改为 `17890` 时，本机只需要：

```text
SERVER_EDGE_PROXY_EGRESS_PORT=17890
```

未覆盖参数继续继承当前 Release 默认值。

部署命令：

```bash
curl -fsSL \
  https://raw.githubusercontent.com/fongap/server-edge/<REF>/install/bootstrap.sh \
  | sudo bash -s -- \
      --repo fongap/server-edge \
      --ref <REF> \
      --instance-source <LOCAL_DIRECTORY>
```

`--instance-source` 必须是目标主机上的本地目录。Secret 不应作为 CLI 参数传入。

手工使用临时实例目录时，应限制目录权限，并在部署完成后删除临时副本。

## 5. 路径 C：GitHub Environment 私密部署

多主机部署推荐使用私密控制面。每台主机使用独立 GitHub Environment：

```text
server-edge-oracle-main
server-edge-oracle-backup
server-edge-dell-home
```

命名规则：

```text
server-edge-<host-id>
```

不同 Environment 的 Variables / Secrets 相互隔离。

当前维护者实现位于私密 `internal-vault/server-edge-environments`，但 Server Edge 公开仓库并不依赖该私密仓库；其他控制面只要能生成相同的本地 `instance-source` 即可。

### 5.1 Environment Variables

必需：

```text
SERVER_EDGE_TARGET_HOST
SERVER_EDGE_TARGET_USER
SERVER_EDGE_SSH_KNOWN_HOSTS
SERVER_EDGE_CONFIG_BUNDLE
```

可选：

```text
SERVER_EDGE_TARGET_PORT   默认 22
SERVER_EDGE_TARGET_ROOT   默认 /opt/server-edge
SERVER_EDGE_PROFILE       默认 profiles/default.json
```

`SERVER_EDGE_CONFIG_BUNDLE` 是非敏感 JSON 配置包：

```json
{
  "schema_version": 1,
  "files": {
    "infra.env": "SERVER_EDGE_INFRA_OVERLAY=auto\n",
    "proxy-hub.env": "SERVER_EDGE_PROXY_EGRESS_PORT=7890\n",
    "publications.json": "{\"schema_version\":1,\"services\":{}}\n"
  }
}
```

不要把 API Key、Token、密码、私钥等敏感值放进这个 Variable。

### 5.2 Environment Secrets

必需：

```text
SERVER_EDGE_SSH_PRIVATE_KEY
SERVER_EDGE_SECRETS_BUNDLE
```

`SERVER_EDGE_SECRETS_BUNDLE` 使用同一个包装格式，但文件名表示最终写入 `/opt/server-edge/secrets/` 的相对路径：

```json
{
  "schema_version": 1,
  "files": {
    "proxy-hub/providers/primary.url": "<secret value>",
    "proxy-hub/controller-secret": "<secret value>",
    "proxy-hub/subscription-token": "<secret value>"
  }
}
```

这些示例只表示结构。真实 Secret 值只应填写在 GitHub Environment Secret 中，不提交到 Git。

### 5.3 SSH 主机身份

`SERVER_EDGE_SSH_KNOWN_HOSTS` 必须预先保存已经核验的目标主机 Host Key。

不要在部署过程中临时执行 `ssh-keyscan` 并直接信任结果。应通过可信渠道取得目标主机 Host Key，核对指纹后再写入 Environment Variable。

部署使用：

```text
StrictHostKeyChecking=yes
```

Host Key 不匹配时部署应失败，而不是自动接受新主机身份。

### 5.4 执行部署

在私密控制面运行：

```text
Actions
→ Server Edge Deploy
```

输入：

```text
environment      server-edge-<host-id>
server_edge_ref  固定 Tag 或 Commit SHA
```

实际流程：

```text
GitHub Environment Variables / Secrets
                ↓
私密 Runner 临时目录
                ↓ SSH
目标主机 /tmp/server-edge-instance.*
                ↓
公开 server-edge bootstrap
                ↓
install/configure.sh
                ↓
/opt/server-edge/config/
/opt/server-edge/secrets/
                ↓
模块安装与健康检查
```

部署结束后，私密 Runner 临时目录、临时 SSH Key 文件和目标主机临时 `instance-source` 会被删除。

## 6. Secret 最终放在哪里

运行时 Secret 最终只由模块从目标主机读取：

```text
/opt/server-edge/secrets/<module>/
```

典型布局：

```text
/opt/server-edge/secrets/
└── proxy-hub/
    ├── providers/
    │   └── primary.url
    ├── controller-secret
    └── subscription-token
```

配置导入时 Secret 文件以 root 所有、`0600` 权限写入，Secret 目录使用受限权限。

Secret 不应进入：

```text
公开 Git
README / 示例配置
普通 config/*.env
runtime/contracts
workflow payload
artifact
日志
CLI 参数
```

## 7. 再次部署与配置更新

同一主机再次部署时，外部配置源可以提交新的 `config/` 与 `secrets/` 内容。

Server Edge 通过：

```text
/opt/server-edge/runtime/config-source.manifest
```

记录上一次由该外部配置源管理的文件。

更新规则：

- 新 bundle 中存在的受管文件会更新；
- 上一次受管、但新 bundle 已删除的文件会删除；
- 不属于该配置源管理的本机文件不会被删除；
- 被替换或删除的旧文件先备份到 `/opt/server-edge/backups/configure/`。

因此删除一个 Secret 时，不能只在业务模块中停用它；应同时从新的 Secret Bundle 中删除对应路径，让目标主机同步撤销旧文件。

## 8. Release 更新与实例数据

Release 更新和实例数据生命周期分开：

```text
新 Release
    ↓
releases/ 更新

config/     保留
secrets/    保留
state/      保留
```

外部配置源明确提交的新配置除外。

任何升级都不应因为替换 Release 目录而无条件覆盖或删除现有 `config/`、`secrets/` 和 `state/`。

## 9. 当前失败与恢复边界

当前 `instance-source` 会在模块安装之前应用。应用配置时，旧受管文件会先备份到：

```text
/opt/server-edge/backups/configure/
```

如果后续模块安装或健康检查失败，当前基线不会自动恢复刚刚应用的实例配置。因此排查失败部署时，应同时检查：

```text
/opt/server-edge/config/
/opt/server-edge/secrets/
/opt/server-edge/backups/configure/
```

不要把现有 Patch / Rollback 脚本理解为已经覆盖全部配置回滚语义；项目仍处于开发阶段。

## 10. 常见失败

### SSH 无法连接

检查目标主机是否能从部署 Runner 到达、SSH 端口是否正确、防火墙是否允许连接。

### Host Key 校验失败

重新核对目标主机真实 SSH Host Key。不要为了通过部署而关闭 `StrictHostKeyChecking`。

### `sudo -n true` 失败

部署 SSH 用户没有无交互 sudo 权限。当前私密部署流程不会通过日志或参数传递 sudo 密码。

### Bundle JSON 无效

确认两个 Bundle 都满足：

```json
{
  "schema_version": 1,
  "files": {}
}
```

配置 Bundle 文件名只能是 `*.env` 或 `publications.json`；Secret Bundle 使用安全的相对路径。

### 配置校验失败

检查目标主机对应 override，而不是把整份旧 Release defaults 复制进实例文件。配置格式和字段语义见 `CONFIGURATION.md` 与对应模块 README。

### 模块缺少 Secret

检查对应 GitHub Environment 的 `SERVER_EDGE_SECRETS_BUNDLE` 是否包含模块要求的 Secret 路径。错误信息可以报告缺失的 Secret 名或路径，但不应打印 Secret 值。

## 11. 安全原则

长期保持以下边界：

```text
Public repository
= code + defaults + schemas + installer

Private control plane
= per-host deployment configuration + encrypted GitHub Environment storage

Target host /opt/server-edge/config
= effective instance overrides

Target host /opt/server-edge/secrets
= runtime Secret files
```

Server Edge 模块只依赖本机目录和运行契约，不依赖 GitHub、Internal Vault 或其他配置来源的内部实现。
