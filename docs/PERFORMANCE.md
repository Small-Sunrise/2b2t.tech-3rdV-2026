# 性能调优指南

## spark 性能分析

2b2t 主服已安装 spark 插件。使用以下命令进行性能分析：

```bash
# 在游戏内或控制台执行:
/spark profiler start --timeout 300    # CPU 采样 5 分钟
/spark healthreport                    # 生成健康报告
/spark tps                             # 查看 TPS
/spark gc                              # GC 监控
```

分析报告会输出一个链接，可在浏览器中查看火焰图和详细指标。

## JVM 调优参数

当前主服 JVM 参数（`2b2t/run.sh`）：

| 参数 | 值 | 说明 |
|------|-----|------|
| -Xms / -Xmx | 8G / 8G | 堆内存，固定大小避免 resize 开销 |
| -XX:SoftMaxHeapSize | 6G | ZGC 软性堆上限 |
| GC | ZGC Generational | 低延迟 GC，适合 Minecraft |
| -XX:ZCollectionIntervalMinor | 0.95 | Minor GC 间隔 |
| -XX:ZUncommitDelay | 5s | 延迟释放未使用内存 |
| -XX:+AlwaysPreTouch | enabled | 启动时预分配物理内存 |

## 性能监控指标

- **TPS**: 目标 20 TPS，低于 18 需要调查
- **MSPT**: 目标 < 50ms，峰值 < 100ms
- **GC Pause**: ZGC 目标 < 1ms，最大 < 5ms
- **Chunk Load**: 监控 `spark tps` 中的 chunk 加载耗时

## 压力测试方案

1. **Chunky 预生成区块**: `/chunky start` 可测试 chunk 生成性能
2. **Bot 模拟**: 使用 bots 模拟玩家并发登录
3. **spark profiler**: 关注 `TickLoop`、`EntityTick`、`ChunkProvider` 耗时

## 已知性能插件

| 插件 | 作用 |
|------|------|
| LagFixer | 自动清理掉落物、限制实体 |
| ChunkEntityLimiter | 限制单 chunk 实体数 |
| ChunkDeleter | 清理无用 chunk |
| AntiRedstoneLag | 限制红石频率 |
| spark | 性能分析 |
| Plan | 玩家数据与性能面板 |

## 建议

1. 定期运行 `/spark healthreport` 并检查 TPS 趋势
2. Chunk 预生成完后关闭 Chunky
3. 根据在线人数调整 LagFixer 清理阈值
