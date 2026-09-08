# Server Edge 治理约束

## 1. 最高原则

所有人工、AI、CI 和自动化变更必须遵守：

1. 能力与实现分离。
2. 模块职责单一。
3. 除 `infra` 外，一级能力模块默认可插拔。
4. 模块依赖契约，不依赖内部实现。
5. 配置、状态、数据、Secret 分离。
6. 管理面、入站面、服务面、出站面、数据面分离。
7. 最小暴露、最小权限、最小长期依赖。
8. 故障域隔离。
9. 独立部署、独立升级、独立回滚。
10. 运行期不依赖固定启动顺序。
11. 不因单一软件改变整体架构。
12. 不为未来假设提前引入组件。
13. 删除优先于叠加，简单优先于抽象。
14. 可恢复优先于“一次运行成功”。

## 2. 一级能力域

固定为：

```text
infra/
app-hub/
proxy-hub/
ai-gateway/
ai-workers/
public-edge/
```

未经架构级决策，不新增、删除或改名。

一级目录使用能力名，不使用具体软件名、临时状态或启动序号。

禁止示例：

```text
mihomo/
caddy/
delta/
1-proxy-hub/
new/
misc/
final/
```

## 3. 可插拔约束

`app-hub`、`proxy-hub`、`ai-gateway`、`ai-workers`、`public-edge` 必须支持独立启停、部署、升级、替换和删除。

跨模块只允许通过：

- 明确 API；
- 明确网络端点；
- 明确协议；
- 明确事件；
- 明确配置契约。

禁止：

- 直接读取其他模块 `data/`；
- 依赖其他模块内部文件布局；
- 依赖其他模块数据库 Schema；
- 以固定启动顺序保证运行正确性。

## 4. `infra` 初始化前置

`infra` 是 Provisioning 前置，不是运行期中央编排器。

首次安装、灾难恢复或全量重建时，`infra` 必须先完成：

- 目录树；
- Owner/权限；
- 跨模块网络；
- 存储路径；
- Secret 路径；
- 管理面基础能力。

完成后，各业务模块必须能够独立恢复。

## 5. 网络治理

所有跨模块 `edge_*` 网络由 `infra/network` 唯一声明和创建。

其他模块的 Compose 只能以 `external: true` 引用这些网络，不得重复创建或修改其生命周期。

同一个 Docker Network 只允许放置确实需要直接互访的服务。

禁止把所有模块加入同一个共享 bridge。

网络命名使用职责，不使用软件名。推荐：

```text
edge_ingress_*
edge_service_*
edge_egress_*
edge_data_*
```

## 6. 管理面

Overlay Network 归 `infra/network/overlay` 管理。当前可以由 Tailscale 实现。

用途限于：SSH、节点互联、私有后台、运维和故障恢复。

业务组件不得成为管理面的唯一依赖。

## 7. 公网暴露

默认只有 `public-edge` 可以发布 80/443。

内部容器优先使用 `expose` 或内部网络，不默认使用 `ports`。

数据库、缓存、Proxy Controller、Docker API、内部 Admin API 不得直接暴露公网。

安全边界至少分为：Cloud NSG/Security List、Host Firewall、Docker Port Publishing、Docker Network、Application Auth。

## 8. 出站治理

`proxy-hub` 是统一代理出口能力域。

优先显式 HTTP/SOCKS 代理；默认不使用全局 TUN、宿主透明劫持或大范围 iptables 重定向。

未经论证不引入第二代理核心、第二订阅体系或重复健康检查服务。

## 9. AI Workers 安全边界

`ai-workers` 默认视为高风险执行域。

默认禁止：

```text
privileged: true
network_mode: host
pid: host
ipc: host
/var/run/docker.sock
宿主根目录或无关系统目录挂载
```

必须定义 CPU、Memory、PID、网络、Workspace 和 Secret 授权边界。

原则：Worker 可以执行任务，但不能拥有平台。

## 10. Secret 治理

Secret 不得进入 Git、README、普通配置、示例、日志或测试夹具。

部署前验证仅允许检查：存在、非空、Owner、权限和必要格式。

禁止在验证过程中把真实 Secret 输出到 stdout/stderr；不得为了验证将文件 Secret 转成普通明文环境变量。

优先使用本地受保护文件和 Compose secrets；不强制引入外部 Secret Manager。

## 11. 配置与状态

明确区分：

```text
config   可版本化配置
state    持久业务状态
runtime  临时运行状态
logs     日志
workspace Worker 工作区
secrets  敏感数据
```

运行时不得回写不可变 Release 配置目录。

## 12. 共享大型资产

允许共享模型、索引、数据集等大型不可变资产，但必须：只读、版本化、可校验、不含 Secret、不含运行状态。

共享资产不得成为跨模块共享业务数据库的借口。

## 13. 日志治理

容器默认输出 stdout/stderr，由 `infra` 统一配置 Docker 日志驱动、轮转和磁盘上限。

只有应用明确要求文件日志时才建立模块专用日志目录。

日志不得记录 Token、Password、Authorization Header、Private Key 或完整敏感 URL。

默认不为单节点引入重型日志平台。

## 14. TLS 与内部 PKI

`public-edge` 负责公网 TLS，但不天然承担内部 CA 职责。

如确需内部 PKI，其治理归属 `infra/security`。

同主机受控 Docker 网络默认不强制全链路 TLS；跨主机、不可信网络或明确高敏 RPC 应使用 TLS/mTLS。

## 15. 资源与健康治理

长期运行服务必须有合理资源边界。`ai-workers` 尤其必须限制 CPU、Memory 和 PID。

健康至少区分 process alive、service ready、dependency ready、external dependency healthy。

应用应优先采用有限重试和指数退避。不得通过无上限 CrashLoop 代替依赖治理。

Watchdog/Autoheal 不是默认组件。只有真实服务无法通过自身重试、healthcheck、restart policy 和资源限制可靠恢复时，才允许针对该服务增加最小自动恢复机制；不得为了通用 Autoheal 暴露 Docker Socket。

## 16. Compose 治理

禁止一个覆盖全部能力域的巨型 Compose。

每个能力域维护独立部署单元，并能独立 validate/up/down/restart/upgrade/rollback。

跨模块网络由 `infra` 提供，不通过中央 Compose 强行编排所有生命周期。

## 17. 版本、安装与 Patch

生产安装必须锁定 Tag、Release 或 Commit SHA，不直接追随 `main` 或 `latest`。

安装器只负责引导、校验和调用模块钩子，不允许演化为包含全部业务逻辑的巨型 Shell。

Patch 是正式能力，不等于 `git pull`。Patch 必须声明：来源版本、目标版本、影响模块、数据迁移、备份要求和回滚条件。

部署前必须执行同一个权威验证器。禁止 Install、Patch、CI 分别实现三套互相漂移的校验逻辑。

## 18. 数据与备份

数据库不得直接暴露公网。

运行中的数据库不得只靠直接 `tar data/` 作为可靠备份。不同数据类型必须采用一致性备份方式。

备份必须覆盖：一致性获取、校验、压缩、加密、异地保存、保留策略和恢复测试。

不能恢复的备份不算备份。

## 19. 脚本与单一事实来源

脚本用于胶合、校验、安装、Patch、回滚、备份和恢复，不重复实现成熟组件已有能力。

同一规则只能存在一个权威实现。文档可以解释规则，但不能成为第二套执行逻辑。

## 20. 新组件准入

新常驻组件必须证明至少一项：必要能力缺失、显著提高稳定性/安全性、显著降低复杂度/资源消耗、或替换现有组件。

“以后可能用到”“别人都有”“功能更多”不是准入理由。

默认选择是不新增。

## 21. 架构级变更

下列变更必须单独评审，不得作为普通修复顺带实施：

- 一级能力域增删改名或职责变化；
- 管理面、公网入口或统一出站模型改变；
- 新增代理核心；
- 引入 Kubernetes、Service Mesh 等平台级依赖；
- 打破可插拔原则；
- 大规模改变数据和权限模型。

## 22. AI 修改约束

AI 修改仓库时必须先识别所属能力域，不扩大端口、不扩大权限、不新增无关组件、不顺手重构、不改无关模块、不重复已有规则。

原则：修复只修复，精简只精简，升级只升级。

## 23. 最终约束

> 能力名稳定，具体实现可换。
>
> 模块可以插拔，契约必须稳定。
>
> `infra` 负责初始化底座，不成为运行期中央依赖。
>
> 管理面独立，入口出口分离。
>
> 配置可版本化，状态可恢复，Secret 不入库。
>
> 局部故障不得演变成整机故障。
>
> 任何新增复杂度都必须证明长期价值。
