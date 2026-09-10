# Server Edge 配置模型

Server Edge 将 Release、实例配置、Secret、持久状态和运行发现分开管理。目标是让同一公开 Release 可以部署到不同主机，同时每台主机保留自己的参数与凭据。

本文件只定义数据类别、所有权和生命周期，不重复描述整体架构。

## 1. 数据类别

```text
Release defaults     Release 内默认模板，只读
Instance config      /opt/server-edge/config/
Secrets              /opt/server-edge/secrets/
Persistent state     /opt/server-edge/state/
Runtime state        /opt/server-edge/runtime/
Runtime contracts    /opt/server-edge/runtime/contracts/
Backups              /opt/server-edge/backups/
```

这些目录生命周期不同，不得混用。

## 2. Release 默认值与实例覆盖

模块默认值位于：

```text
<module>/config/defaults.env
```

实例覆盖位于：

```text
/opt/server-edge/config/<module>.env
```

加载关系：

```text
Release defaults
      ↓
Instance overrides
      ↓
Effective settings
```

实例文件只需要保存与默认值不同的参数。首次安装如果没有实例覆盖文件，只创建最小 override 文件，不复制整份 Release defaults。

因此新 Release 增加默认参数时，旧主机可以直接继承新默认值；显式写入实例文件的参数仍保持主机自己的选择。

规则：

- 默认模板属于 Release；
- 实例配置属于当前 Server Edge 实例；
- 升级不得覆盖已有实例值；
- 实例文件不需要重复保存所有默认参数；
- 尚未实现实际运行参数的模块，不提前创建空实例配置。

## 3. 配置所有权

模块只能读取自己的实例配置。

禁止：

```text
ai-gateway 读取 proxy-hub.env
public-edge 读取 proxy-hub.env
app-hub 读取 ai-gateway.env
```

如果一个值需要被其他模块消费，应判断它属于平台级策略、跨模块运行契约、Secret 或业务 API 数据，不得通过读取另一个模块的 `.env` 形成隐式耦合。

## 4. 平台级配置

不属于单一业务模块所有权的实例策略，可以放在平台级配置中。

当前平台级公网发布注册表为：

```text
/opt/server-edge/config/publications.json
```

Release 默认文件：

```text
config/publications.default.json
```

业务模块声明稳定 `publication_key` 和内部服务端点，Public Edge 根据平台发布注册表决定是否建立公网域名、TLS 和反向代理。

公网域名因此不属于 `proxy-hub.env`、`ai-gateway.env` 或其他业务模块私有配置。

## 5. Secret

Secret 统一放在：

```text
/opt/server-edge/secrets/<module>/
```

Secret 与普通配置分开，因为两者权限、生命周期、日志要求和备份策略不同。

规则：

- Secret 不进入公开 Git 仓库；
- Secret 不写入普通 `.env` 示例；
- Secret 不进入 runtime contracts；
- Secret 不在验证或日志中打印；
- 模块只读取自己被授权的 Secret；
- Secret 文件及其目录使用最小权限；
- 不为了传递方便把文件 Secret 转成跨模块明文环境变量。

具体 Secret 的格式由所属模块定义。

## 6. 外部实例配置源

Server Edge 不负责保存远端私密配置，也不直接连接 GitHub 私密仓库。外部控制面可以先把某台主机的配置与 Secret 写入目标主机上的临时目录，再把这个目录交给安装器。

约定结构：

```text
<instance-source>/
├── config/
│   ├── infra.env
│   ├── proxy-hub.env
│   └── publications.json
└── secrets/
    └── <module>/...
```

Bootstrap 支持：

```bash
--instance-source <LOCAL_DIRECTORY>
```

安装顺序为：

```text
下载公开 Release
      ↓
Host bootstrap
      ↓
校验并应用 instance source
      ↓
/opt/server-edge/config/
/opt/server-edge/secrets/
      ↓
模块 validate / install / healthcheck
```

`install/configure.sh` 只接受本地目录。它不读取远程仓库、不接受 Secret CLI 值、不持有 GitHub Token。

外部配置源只负责“把数据送到本机”；一旦落地，业务模块不知道配置来自手工、本地文件、GitHub Environment 或其他控制面。

## 7. 配置源更新语义

由 `install/configure.sh` 导入的文件属于“外部源托管文件”。Server Edge 在：

```text
/opt/server-edge/runtime/config-source.manifest
```

记录这些文件的相对路径。

下一次导入时：

- 新源中的文件会更新；
- 上一次由外部源托管、但新源已经删除的文件会删除；
- 不在托管清单中的本机文件不受影响；
- 被替换或删除的旧文件先备份到 `/opt/server-edge/backups/configure/`；
- 配置与 Secret 的实际值不会写入 runtime contract 或安装日志。

这允许远端配置源成为自己管理范围内的权威来源，同时不接管本机其他未托管数据。

## 8. 持久状态

持久业务状态统一放在：

```text
/opt/server-edge/state/<module>/
```

`state/` 与 Release 分离，升级或切换代码版本不得因为替换 Release 目录而自动删除状态。

一个模块不得直接读取另一个模块的 `state/`。需要共享的数据应通过明确 API、协议或经过治理的只读共享资产提供。

## 9. Runtime 状态

可重新生成的运行数据放在：

```text
/opt/server-edge/runtime/
```

例如渲染后的 Compose、临时运行环境文件、Host facts 和跨模块运行契约。

`runtime/` 不应成为长期业务数据或 Secret 的存放位置。

## 10. 跨模块运行契约

跨模块动态发现统一使用：

```text
/opt/server-edge/runtime/contracts/
```

运行契约用于描述消费者真正需要知道的运行事实，例如 service identity、protocol、endpoint、network、publication_key 和 optional capability state。

运行契约必须最小、机器可读、可重新生成、不包含 Secret、不暴露生产者内部文件结构，也不要求消费者读取生产者 `.env`。

## 11. Shared Assets

大型不可变共享资产可以放在：

```text
/opt/server-edge/shared/assets/
```

适合模型、索引、数据集等只读内容。共享资产必须可版本化、可校验、不含 Secret、不承载运行状态，也不得演变成跨模块共享业务数据库。

## 12. 备份

备份统一归：

```text
/opt/server-edge/backups/
```

不同数据类别应采用与其一致性要求匹配的备份方式。`state/` 中的数据库等一致性数据不能简单以运行中目录打包代替可靠备份。

外部配置源更新产生的旧配置快照也只保留在本机备份目录，不上传到公开仓库。

## 13. 配置变更原则

应满足：

- 同一 Release 可以部署到多台配置不同的主机；
- 修改域名，不要求修改业务模块代码；
- 修改模块内部端口，不要求消费者同步硬编码；
- 修改 Proxy Hub 节点参数，不影响公网发布策略；
- 切换具体软件版本，不自动覆盖实例业务参数；
- Secret 不转移到普通配置；
- Release 替换不覆盖 `config/`、`secrets/` 或 `state/`；
- 外部控制面不能绕过本机配置校验；
- 不为待开发模块提前创建无用途配置。

## 14. 机器事实

当前机器可读配置规则位于 `manifests/`。

文档负责说明语义；机器校验应读取权威事实，而不是在多个脚本和文档中分别维护另一套规则。
