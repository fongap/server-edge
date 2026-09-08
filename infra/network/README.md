# Network

跨模块 `edge_*` 网络由此处唯一声明和创建。业务模块只能按 `external: true` 引用。

- `overlay/`：管理面覆盖网络，当前可由 Tailscale 实现。
- `container/`：Docker/容器网络契约。
