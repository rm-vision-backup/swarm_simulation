# bashs：15 机 PX4 SITL 单轮整套测试脚本（正式入库）

> 来源：`.tmp/headless_test/{run,cleanup,status,env}.sh` 与 `.tmp/scripts/run_15uav_prepare.sh`
> （该编排用于 2026-08-30 ~ 2026-09-07 的 prepare 验收，见
> `src/tcp_to_ros/test_records/test_record_26090722.md`、`test_record_26090106.md`）。
> 本目录是其受版本控制的正式化版本，后续 SITL 单轮测试一律使用这里，不再依赖 `.tmp`。
> 正式版五次 prepare 复测（2026-09-08，无 HOLD 注入，`schedule_safety_margin_m=1.0`）：
> - 首轮（26090802 已实施源码）`src/tcp_to_ros/test_records/test_record_26090814.md`：**1/5 SUCCESS（R4）**；
> - 26090802 源码回退后 `src/tcp_to_ros/test_records/test_record_26090816.md`：**4/5 SUCCESS（R1–R4）**，
>   R5 FAIL（A05/A06），失败轮 `.ros_home_round5` 留档。


## 文件

| 文件 | 作用 |
|---|---|
| `env.sh` | 公共环境（PX4/Gazebo/ROS master 11300、11310、UAV 11311..11325；日志 → `.ros_home/log/headless_test`） |
| `phases.sh` | 分阶段控制：`sim / onboard / gcs_bridge_only / gcs_backend_only / tcp / takeoff / task / uav_z / status / cleanup` |
| `status.sh` | 各层就绪状态汇总 |
| `cleanup.sh` | 逆序精确停止（PID/进程组）+ bridge ZMQ 残留兜底 + 端口/进程检查 |
| `round_prepare_15sitl.sh` | **整套单轮**：clean → 隔离 `.ros_home` → sim → onboard → gcs(bridge→backend+标定) → tcp → takeoff → prepare → RESULT → 失败轮 `.ros_home_roundN` → cleanup |

## 单轮用法

```bash
# 工作区环境（catkin devel 已 build）
cd /home/yjq/catkin_swarm6-2
source /opt/ros/noetic/setup.bash && source devel/setup.bash

# 单轮 prepare（默认）
bash src/swarm_simulation/bashs/round_prepare_15sitl.sh --round 1

# 指定任务/超时/是否留档失败日志
bash src/swarm_simulation/bashs/round_prepare_15sitl.sh \
  --round 3 --task prepare --timeout-s 150 --keep-ros-home-on-fail 1
```

- 退出码：`0` = prepare SUCCESS；`1` = 失败（`--round N` + `--keep-ros-home-on-fail 1` 时已把
  本轮 `.ros_home`（含 `sitl_iris_*` PX4 ulog）复制为 `.ros_home_roundN`）；`2` = 用法错。
- 无论成功/失败，脚本结束都执行 cleanup（进程 0、端口 clean）。运行耗时约 6–10 分钟/轮
  （onboard/取off/标定等待为主）。
- 中途按 Ctrl-C 会触发 `trap cleanup EXIT`，同样清理。

## 阶段脚本独立用法

```bash
bash src/swarm_simulation/bashs/phases.sh sim
bash src/swarm_simulation/bashs/phases.sh onboard
bash src/swarm_simulation/bashs/phases.sh gcs_bridge_only
bash src/swarm_simulation/bashs/phases.sh gcs_backend_only
bash src/swarm_simulation/bashs/phases.sh tcp
bash src/swarm_simulation/bashs/phases.sh takeoff
bash src/swarm_simulation/bashs/phases.sh task prepare 150
bash src/swarm_simulation/bashs/status.sh
bash src/swarm_simulation/bashs/cleanup.sh
```

注意：GCS 组合必须用 `gcs_bridge_only` → 等 master 11310 就绪 → `gcs_backend_only`
（两个 roslaunch 同时 auto-start 同 master 会 XML-RPC 竞态）；标定在 disarm 后完成
`/group_a/calibration_ready=true` 才允许 takeoff。
