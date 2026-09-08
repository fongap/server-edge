# Host Adapter

`infra/host` 是 Server Edge 唯一的宿主适配入口。

它负责把不同 Linux 主机统一映射到 `docs/HOST-CONTRACT.md` 定义的能力模型。

## 职责

允许处理：

- Linux 与 CPU 架构探测；
- 云端、本地或未知环境识别；
- 包管理器识别；
- 服务管理器识别；
- 基础依赖检查与安装；
- Docker Engine + Compose 能力检查；
- 宿主级文件系统与网络能力检查；
- 标准化 Host Facts 输出。

## 禁止

不得处理：

- `app-hub`、`proxy-hub`、`ai-gateway`、`ai-workers`、`public-edge` 的业务配置；
- 云厂商专用业务逻辑；
- Profile 选择；
- 代理规则、域名、模型或应用配置。

上层模块不得反向读取 `/etc/os-release`、包管理器或云厂商 Metadata 来决定自身行为。

## 设计原则

优先检测能力，而不是判断发行版名称。

如果未知 Linux 已经满足 Host Contract，应允许以 `Compatible` 状态继续部署。

初期只实现真实需要和真实验证的平台，不预建大量空 Adapter。

后续实现建议：

```text
infra/host/
├── detect.sh
├── validate.sh
└── adapters/
    ├── package/
    └── service/
```

实际子目录仅在存在真实实现时创建。
