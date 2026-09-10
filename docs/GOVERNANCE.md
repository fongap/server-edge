# Server Edge 治理约束

本文件只定义开发与变更必须遵守的红线。架构解释见 `ARCHITECTURE.md`，宿主能力见 `HOST-CONTRACT.md`，配置模型见 `CONFIGURATION.md`。

## 1. 最高原则

所有人工、AI、CI 和自动化变更必须遵守：

1. 能力与具体实现分离。
2. 一级能力域保持稳定，模块职责单一。
3. 除 `infra` 外，业务能力默认可插拔。
4. 模块依赖明确契约，不依赖其他模块内部实现。
5. 宿主差异只能进入 `infra/host`。
6. 配置、Secret、状态、运行数据分离。
7. 公网入口、管理面和代理出口职责分离。
8. 跨模块网络按真实通信关系创建。
9. 最小暴露、最小权限、最小长期依赖。
10. 不为未来假设提前引入组件。
11. 删除优先于叠加，简单优先于抽象。
12. 可恢复性优先于一次运行成功。

## 2. 一级能力域

一级能力域固定为：

```text
infra/
app-hub/
proxy-hub/
ai-gateway/
ai-workers/
public-edge/
```

未经独立架构评审，不得新增、删除、改名或改变其长期职责。

一级目录必须使用能力名，不得使用具体软件名、云厂商名、发行版名、临时状态或启动序号。

禁止示例：

```text
mihomo/
caddy/
delta/
oracle/
ubuntu/
1-proxy-hub/
new/
final/
misc/
```

## 3. 宿主边界

`infra/host` 是唯一宿主适配入口。

`app-hub`、`proxy-hub`、`ai-gateway`、`ai-workers`、`public-edge` 不得包含针对 Oracle、AWS、Ubuntu、Debian、apt、dnf、systemd 等宿主环境的判断逻辑。

Host 是否可部署，以 Host Contract 的能力判断为准，不以云厂商或发行版名称判断。

Profile 只描述启用哪些能力，不得描述宿主环境，因此不得建立 `oracle.json`、`ubuntu.json`、`home-server.json` 等环境型 Profile。

## 4. Runtime 边界

当前统一容器 Runtime 为 Docker Engine + Compose v2。

不得为了未来兼容性提前引入 Podman 双运行时、Kubernetes、Service Mesh 或第二套编排系统。引入第二 Runtime 属于架构级变更。

`infra` 是首次 Provisioning 前置，不得演化为运行期中央编排器。

禁止一个 Compose 文件统一控制全部能力域。每个能力域应拥有独立生命周期。

## 5. 模块依赖

跨模块只允许通过明确、最小的接口发生依赖，例如：

- API；
- 明确协议的网络端点；
- Feed；
- 事件；
- 运行契约。

禁止：

- 读取其他模块 `.env`；
- 读取其他模块 `state/`；
- 依赖其他模块内部文件布局；
- 直接依赖其他模块数据库 Schema；
- 通过固定启动顺序保证正确性；
- 把 Secret 写进运行契约。

## 6. 配置、Secret 与状态

必须区分：

```text
Release defaults   Release 内默认值
config             实例非敏感配置
secrets            敏感数据
state              持久业务状态
runtime            可重建运行状态
runtime/contracts  跨模块运行发现
```

运行服务不得修改不可变 Release 内容。

Secret 不得进入 Git、README、普通配置、示例、日志或测试夹具，也不得为了验证方便转成普通明文环境变量输出。

模块只能读取自己被授权的 Secret。

## 7. 网络与暴露

所有跨模块 `edge_*` Docker Network 由 `infra/network` 唯一创建和维护；其他模块只能引用，不得重复声明生命周期。

网络只在存在真实通信关系时创建。不得为了架构图完整性提前为尚未实现的模块创建网络。

禁止所有模块加入同一个无边界共享 bridge。

默认只有 `public-edge` 管理公网 `80/443`。

数据库、缓存、Proxy Controller、Docker API、内部 Admin API 不得直接暴露公网。

Overlay Network 归 `infra/network/overlay` 管理，用于 SSH、私有管理、节点互联和恢复，不属于 Proxy Hub 的业务代理出口。

## 8. Proxy Hub

`proxy-hub` 负责节点聚合、订阅能力与可选显式出口。

默认不使用全局 TUN、宿主透明劫持或大范围 iptables 重定向。

未经明确需求，不增加第二代理核心、第二订阅体系或重复健康检查服务。

## 9. Public Edge

公网域名、TLS 和反向代理统一归 `public-edge`。

业务模块不得直接拥有平台公网 `80/443`，也不得把公网域名作为内部模块耦合条件。

Public Edge 只能消费业务服务契约和平台发布配置，不得读取业务模块 Secret、状态目录或私有配置。

## 10. AI Workers

`ai-workers` 默认视为高风险执行域。

除非经过独立安全评审，禁止：

```text
privileged: true
network_mode: host
pid: host
ipc: host
/var/run/docker.sock
宿主根目录挂载
无关系统目录挂载
```

Worker 必须定义 CPU、Memory、PID、网络、Workspace 和 Secret 授权边界。

原则：Worker 可以执行任务，但不能拥有平台。

## 11. 资源、健康与恢复

长期运行服务应设置合理资源边界和健康检查。

健康状态应区分至少：进程存活、服务就绪、必要依赖就绪。外部依赖异常不得简单通过无限 CrashLoop 处理。

优先使用应用自身重试、指数退避、Compose healthcheck 和 restart policy。不得为了通用 Autoheal 暴露 Docker Socket。

备份只有经过恢复验证才视为有效。数据库等一致性数据不得只依赖直接打包运行目录作为备份方案。

## 12. 安装、Patch 与回滚

生产或长期运行安装必须锁定 Tag、Release 或 Commit SHA，不直接追随 `main` 或 `latest`。

安装器只负责引导、Host 检测、校验和调用模块生命周期，不得演化成承载全部业务逻辑的巨型 Shell。

Patch 必须声明来源版本、目标版本、影响模块、必要备份、数据迁移和回滚条件。Patch 不等于 `git pull`。

Install、Patch、CI 不得各自维护互相漂移的同类校验规则。

当前项目仍处于开发阶段；存在 Patch 或 Rollback 脚本不等于已经形成稳定生产升级承诺。对外文档必须如实描述实现成熟度。

## 13. 版本治理

Server Edge 版本号变更属于独立发布决策，不由开发里程碑、文档调整、CI 通过或实机验证自动触发。

任何对 `VERSION` 或 `manifests/versions.json` 中 `server_edge` 的修改，必须先提出明确目标版本并获得项目所有者明确批准。

没有明确批准时，开发、修复、文档整理和验证都保持当前版本号不变。

## 14. 单一事实来源

机器可执行事实优先放在 `manifests/` 或其权威实现中；文档负责解释，不建立第二套执行逻辑。

同一机器规则不应同时在多个脚本中手工复制。验证器应消费事实，而不是重新发明事实。

文档之间也必须分工：

- `ARCHITECTURE.md`：解释长期结构；
- `GOVERNANCE.md`：规定红线；
- `HOST-CONTRACT.md`：定义宿主要求；
- `CONFIGURATION.md`：定义配置与数据所有权；
- 模块 README：描述当前真实实现。

## 15. 新组件准入

新增常驻组件必须满足至少一项：

- 解决已经出现的必要能力缺口；
- 显著提升稳定性或安全性；
- 显著降低复杂度或资源消耗；
- 明确替换现有组件。

“以后可能需要”“别人都有”“功能更多”不是准入理由。

默认选择是不新增。

## 16. 架构级变更

以下变化必须单独评审，不能作为普通功能或修复顺带实施：

- 一级能力域增删、改名或职责改变；
- Host Contract 基础模型改变；
- 管理面、公网入口或统一出站模型改变；
- 引入第二容器 Runtime 或第二平台级代理体系；
- 引入 Kubernetes、Service Mesh 等平台级依赖；
- 打破模块可插拔、配置分离或最小权限原则。

## 17. AI 修改约束

AI 修改仓库时必须先确定变更所属能力域和事实来源。

AI 不得：

- 因局部问题扩大一级架构；
- 擅自升级 Server Edge 版本；
- 为未来场景提前新增组件；
- 在多个位置重复实现同一规则；
- 把示例、猜测或规划写成已完成事实；
- 在未经要求时顺带重构无关模块。

AI 输出和提交应优先采用最小、可验证、可回退的变更。