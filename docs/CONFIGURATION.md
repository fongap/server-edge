# Server Edge 配置模型

Server Edge 将 Release、实例配置、Secret、持久状态和运行发现分开管理。目标是让模块能够独立部署和替换，同时避免通过共享 `.env`、固定端口或内部文件形成隐式耦合。

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

## 2. Release 默认值与实例配置

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

规则：

- 默认模板属于 Release；
- 实例配置属于当前 Server Edge 实例；
- 首次安装可以根据默认模板初始化实例配置；
- 后续升级不得覆盖已有实例值；
- 新 Release 增加默认参数时，不要求手工把所有默认值复制进实例文件；
- 尚未实现实际运行参数的模块，不提前创建空实例配置。

当前已接入该模型的模块包括：

```text
infra/config/defaults.env
    -> /opt/server-edge/config/infra.env

proxy-hub/config/defaults.env
    -> /opt/server-edge/config/proxy-hub.env
```

其他模块应在真正开始实现运行参数时再接入。

## 3. 配置所有权

模块只能读取自己的实例配置。

禁止：

```text
ai-gateway 读取 proxy-hub.env
public-edge 读取 proxy-hub.env
app-hub 读取 ai-gateway.env
```

如果一个值需要被其他模块消费，应判断它属于：

- 平台级策略；
- 跨模块运行契约；
- Secret；
- 业务 API 数据。

不得通过“顺手读取另一个模块的配置文件”解决跨模块依赖。

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

示例：

```json
{
  "schema_version": 1,
  "services": {
    "proxy-subscription": {"origin": "https://sub.example.com"},
    "ai-gateway": {"origin": "https://api.example.com"}
  }
}
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

- Secret 不进入 Git；
- Secret 不写入普通 `.env` 示例；
- Secret 不进入 runtime contracts；
- Secret 不在验证或日志中打印；
- 模块只读取自己被授权的 Secret；
- 不为了传递方便把文件 Secret 转成跨模块明文环境变量。

具体 Secret 的格式由所属模块定义。

## 6. 持久状态

持久业务状态统一放在：

```text
/opt/server-edge/state/<module>/
```

`state/` 与 Release 分离，升级或切换代码版本不得因为替换 Release 目录而自动删除状态。

一个模块不得直接读取另一个模块的 `state/`。需要共享的数据应通过明确 API、协议或经过治理的只读共享资产提供。

## 7. Runtime 状态

可重新生成的运行数据放在：

```text
/opt/server-edge/runtime/
```

例如：

- 渲染后的 Compose；
- 临时运行环境文件；
- Host facts；
- 跨模块运行契约。

`runtime/` 不应成为长期业务数据或 Secret 的存放位置。

## 8. 跨模块运行契约

跨模块动态发现统一使用：

```text
/opt/server-edge/runtime/contracts/
```

运行契约用于描述消费者真正需要知道的运行事实，例如：

```text
service identity
protocol
endpoint
network
publication_key
optional capability state
```

运行契约必须：

- 最小；
- 机器可读；
- 可重新生成；
- 不包含 Secret；
- 不暴露生产者内部文件结构；
- 不要求消费者读取生产者 `.env`。

例如 Proxy Hub 的统一出口端口可配置，因此 AI Gateway 或 AI Workers 应消费 `proxy-egress` 契约，而不是硬编码 `proxy-hub:7890`。

## 9. Shared Assets

大型不可变共享资产可以放在：

```text
/opt/server-edge/shared/assets/
```

适合模型、索引、数据集等只读内容。

共享资产必须可版本化、可校验、不含 Secret、不承载运行状态，也不得演变成跨模块共享业务数据库。

## 10. 备份

备份统一归：

```text
/opt/server-edge/backups/
```

不同数据类别应采用与其一致性要求匹配的备份方式。`state/` 中的数据库等一致性数据不能简单以运行中目录打包代替可靠备份。

备份策略和恢复动作由相应模块与 Infra 的恢复能力共同定义。

## 11. 配置变更原则

应满足：

- 修改域名，不要求修改业务模块代码；
- 修改模块内部端口，不要求消费者同步硬编码；
- 修改 Proxy Hub 节点参数，不影响公网发布策略；
- 关闭可选统一出口，不关闭节点聚合；
- 切换具体软件版本，不自动覆盖实例业务参数；
- Secret 不转移到普通配置；
- 重复安装不覆盖已有实例配置；
- 不为待开发模块提前创建无用途配置。

## 12. 机器事实

当前机器可读配置规则位于 `manifests/`。

文档负责说明语义；机器校验应读取权威事实，而不是在多个脚本和文档中分别维护另一套规则。