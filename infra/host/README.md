# Host Adapter

`infra/host` 是 Server Edge 唯一的宿主差异适配入口。

它负责把不同 Linux 主机统一映射到 `docs/HOST-CONTRACT.md` 定义的能力模型。

## M1 实现

```text
infra/host/
├── detect.sh
├── validate.sh
├── bootstrap.sh
└── adapters/
    └── package/
        └── apt.sh
```

- `detect.sh`：输出标准化 Host Facts，不修改系统。
- `validate.sh`：校验 Host Contract；未知 Linux 在运行时已满足时允许以 Compatible 方式继续。
- `bootstrap.sh`：补齐最小工具与容器运行时，然后写入 `runtime/host.env`。
- `adapters/package/apt.sh`：当前首个 Package Adapter，仅负责 apt 系基础依赖。

当前自动安装路径覆盖 Ubuntu/Debian + systemd；其他 Linux 如果已经具备兼容 Docker Engine + Compose，可继续部署。

## 职责

允许处理：Linux/CPU 探测、包管理器与服务管理器识别、基础依赖、Docker Runtime 能力检查、宿主文件系统与网络能力检查、Host Facts 输出。

## 禁止

不得处理 `app-hub`、`proxy-hub`、`ai-gateway`、`ai-workers`、`public-edge` 的业务配置，不得创建云厂商专用业务逻辑，不负责 Profile 选择。

上层模块不得反向读取 `/etc/os-release`、包管理器或云厂商 Metadata 来决定自身行为。

## 原则

优先检测能力，不按发行版名称设计上层逻辑；已有依赖优先复用；Adapter 必须幂等；不预建未实际使用的 dnf/apk/pacman/zypper Adapter。
