# Proxy Hub Config

Mihomo 的最终运行配置不进入 Git，也不包含真实订阅 URL。

配置由 `proxy-hub/scripts/render-config.sh` 根据受保护的 Provider URL 文件生成到：

```text
/opt/server-edge/runtime/proxy-hub/config.yaml
```

运行配置权限为 `0600`。策略的权威实现位于渲染脚本，Secret 的权威来源位于 `/opt/server-edge/secrets/proxy-hub/`。
