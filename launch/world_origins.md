# 15 机编队 SITL 场景世界坐标记录

三个场景共用 `multi_uav_ego_15sim.launch`，由 `bashs/gen_multi_uav_ego_15sim.py`
生成。可执行来源只有脚本顶部的 `HOME_LAT` / `HOME_LON` / `HOME_ALT` 与
`REF_YAW_DEG`，本文件仅作记录与复盘。

## 坐标与朝向约定

- 任务/世界坐标：右 x / 前 y / 上 z。
- Gazebo/ROS ENU yaw：东 = 0°，逆时针为正（0 = 世界 +x）。
- PX4 `compass_hdg` 罗盘：北 = 0°，顺时针为正。
- 换算：`yaw_enu = 90° − compass_hdg`。
- 每机实际机头 = `REF_YAW_DEG` + 随机偏差（±12°）。

## 三个场景的初始世界坐标

| 场景 | 原点 (lat, lon, alt/m) | ENU yaw | 罗盘 | 说明 | 提交（子模块 / 主仓） |
|---|---|---|---|---|---|
| 渡海登岛 | 38.4983052, 103.2063739, 1345.86 | −82.8° | 172.8° | 实测 home 原始点 | `b9ce963` / `c30e3ca` |
| 城镇 | 38.4984849, 103.2063739, 1345.86 | 97.2° | −7.2°（352.8°） | 原 home 北移 20.004 m，再转 180° | `5fc8962` / `29e77c5` |
| 山地丛林 | 38.4997783, 103.2054728, 1348.66 | 123.59° | 326.41° | 2026-10-22 UAV11 机载实测 home | `3173d2b` / `de5d893` |

## 注意

- 三套值写入同一组常量，HEAD 只保留当前场景（山地丛林）；前两套见上表对应
  提交的 diff 与提交信息。
- 山地丛林仅更新参数并重新生成 launch，未跑 SITL。渡海登岛、城镇的轮次与结果
  见 `quality_reports/2026-10-22_two_teams_recon_sitl_origins.md`（本地记录，未入库）。
- 地理原点/朝向只影响出生位姿、QGC 地图位置与标定参考；任务坐标始终相对
  标定原点。

## 重新生成

```bash
python3 src/swarm_simulation/bashs/gen_multi_uav_ego_15sim.py
```
