# Server Edge

Server Edge 是面向长期运行边缘节点的模块化部署底座。一级能力域固定为：

```text
server-edge/
├── infra/
├── app-hub/
├── proxy-hub/
├── ai-gateway/
├── ai-workers/
└── public-edge/
```

`infra` 是初始化与管理底座；其余五个模块均为可插拔能力。能力名稳定，具体实现可替换。

## 文档

- `ARCHITECTURE.md`：定义系统组成、边界、网络与运行模型。
- `GOVERNANCE.md`：定义允许和禁止的变更。
- `manifests/`：定义可机器校验的系统契约。
- `profiles/`：选择本节点启用的能力模块。
- `install/`：安装、Patch、回滚和验证入口。

## GitHub 安装

生产安装应锁定 Tag、Release 或 Commit SHA，不直接跟随 `main`。

公开仓库可直接取得引导脚本：

```bash
curl -fsSL \
  https://raw.githubusercontent.com/fongap/server-edge/<REF>/install/bootstrap.sh \
  | sudo bash -s -- --repo fongap/server-edge --ref <REF>
```

私有仓库可通过 GitHub API 获取引导脚本：

```bash
curl -fsSL \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.raw+json" \
  "https://api.github.com/repos/fongap/server-edge/contents/install/bootstrap.sh?ref=<REF>" \
  | sudo -E bash -s -- --repo fongap/server-edge --ref <REF>
```

默认安装根目录：`/opt/server-edge`。

## Profile

```bash
sudo /opt/server-edge/current/install/install.sh \
  --root /opt/server-edge \
  --profile profiles/default.json
```

`profiles/default.json` 默认启用全部能力域；可复制后按节点用途关闭不需要的插件模块。

## Patch

Patch 是 release-to-release 的受控变更，不等于 `git pull`：

```bash
sudo /opt/server-edge/current/install/patch.sh --ref <TARGET_REF>
```

Patch 必须在目标版本 `patches/index.json` 中声明来源版本、变更模块与回滚条件。未声明兼容路径时默认拒绝 Patch。

## 回滚

```bash
sudo /opt/server-edge/current/install/rollback.sh --to <RELEASE_ID>
```

回滚只切换已验证 Release；涉及不可逆数据迁移时必须由对应模块提供恢复钩子。
