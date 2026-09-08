# Server Edge 配置模型

Server Edge 的能力结构固定，实例参数外置。配置目标是让域名、端口、绑定、开关、资源、健康检查和实现参数尽量独立，不要求修改代码或跨模块同步硬编码。

## 1. 四类数据

```text
默认模板   Release 内，只读
实例配置   /opt/server-edge/config/
Secret     /opt/server-edge/secrets/
运行契约   /opt/server-edge/runtime/contracts/
```

默认模板用于首次初始化；实例配置创建后跨 Release 保留，升级不得覆盖。

## 2. 模块配置

模块拥有自己的默认值：

```text
<module>/config/defaults.env
```

实例配置统一落到：

```text
/opt/server-edge/config/<module>.env
```

模块只能读取自己的实例配置。禁止读取另一个模块的 `.env` 来形成隐式耦合。

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

例如 Proxy Hub 可写出统一出口端点，AI Gateway 只消费契约，不硬编码 `7890`。

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
- 修改 LOCAL 节点，不应影响订阅域名；
- 关闭统一出口，不应关闭节点聚合；
- 切换实现版本，不应改实例业务参数；
- Secret 不得转移到普通配置；
- 升级不得覆盖已有实例配置。

机器可读规则见 `manifests/configuration.json`。
