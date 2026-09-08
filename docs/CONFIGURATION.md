# Server Edge 配置模型

Server Edge 的能力结构固定，实例参数外置。配置目标是让域名、端口、绑定、开关、资源、健康检查和实现参数尽量独立，不要求修改代码或跨模块同步硬编码。

## 1. 四类数据

```text
默认模板   Release 内，只读
实例配置   /opt/server-edge/config/
Secret     /opt/server-edge/secrets/
运行契约   /opt/server-edge/runtime/contracts/
```

默认模板属于 Release；实例配置属于当前 Server Edge 实例，两者生命周期不同。

## 2. 模块配置

模块拥有自己的默认值：

```text
<module>/config/defaults.env
```

实例配置统一落到：

```text
/opt/server-edge/config/<module>.env
```

加载顺序固定为：

```text
Release defaults
      ↓
Instance overrides
```

首次安装可由默认模板初始化实例文件；后续升级不得覆盖已有实例文件。即使实例文件只覆盖少量参数，新 Release 增加的默认参数仍可自动生效。

模块只能读取自己的配置。禁止读取另一个模块的 `.env` 来形成隐式耦合。

当前已接入该模型：

```text
infra/config/defaults.env      -> /opt/server-edge/config/infra.env
proxy-hub/config/defaults.env  -> /opt/server-edge/config/proxy-hub.env
```

尚未实现实际运行参数的模块，不提前创建空配置文件。

## 3. 域名与公网发布

域名不属于某个业务模块的内部参数。Server Edge 使用平台级发布注册表：

```text
/opt/server-edge/config/publications.json
```

默认文件：

```text
config/publications.default.json
```

示例：

```json
{
  "schema_version": 1,
  "services": {
    "proxy-subscription": {"origin": "https://sub.example.com"},
    "ai-gateway": {"origin": "https://api.example.com"},
    "app-main": {"origin": "https://app.example.com"}
  }
}
```

服务 ID 稳定，Origin 可修改。Origin 只允许规范 HTTPS Origin，不带路径或端口。

业务模块只声明内部服务契约；`public-edge` 根据 `publication_key` 与发布注册表决定是否创建公网域名、TLS 和反向代理。

## 4. 跨模块契约

跨模块参数不得通过读取对方配置传递。必须使用最小、机器可读、无 Secret 的运行契约：

```text
/opt/server-edge/runtime/contracts/
```

例如 Proxy Hub 写出统一出口端点，AI Gateway 只消费契约，不硬编码具体端口。

## 5. 配置所有权

```text
平台级发布策略       config/publications.json
模块业务参数         config/<module>.env
Secret               secrets/<module>/
运行发现/端点         runtime/contracts/*.json
版本与实现锁定       manifests/versions.json
Profile 模块组合      profiles/*.json
```

这些职责不得混用。

## 6. 变更原则

- 修改域名，不应修改业务模块代码；
- 修改端口，不应要求消费者模块同步硬编码；
- 修改节点参数，不应影响域名发布策略；
- 关闭可选出口，不应关闭节点聚合；
- 切换实现版本，不应改实例业务参数；
- Secret 不得转移到普通配置；
- 重复安装不得覆盖实例配置；
- 升级新增默认参数必须兼容已有实例覆盖；
- 不为尚未实现的模块预建空配置。

机器可读规则见 `manifests/configuration.json`。
