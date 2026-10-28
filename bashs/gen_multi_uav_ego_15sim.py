#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成 swarm_simulation/launch/multi_uav_ego_15sim.launch（15 机带摆放误差的编队）。

用法（改完下面的常量后运行）：
    python3 src/swarm_simulation/bashs/gen_multi_uav_ego_15sim.py

编队（5 排 × 3 列，行优先编号，UAV1 为前-右角；"右/后" 按参考朝向 REF_YAW_DEG 定义）：
    第5排: UAV13 UAV14 UAV15
    第4排: UAV10 UAV11 UAV12
    第3排: UAV7  UAV8  UAV9
    第2排: UAV4  UAV5  UAV6
    第1排: UAV1  UAV2  UAV3

每机生成位置 = 参考偏置 + (δx, δy)、z = 0.5 + δz；
x/y 偏差 |δ| < POS_JITTER_M，z 偏差 |δz| < POS_JITTER_M * Z_JITTER_SCALE；
生成偏航 = 参考偏航 + δψ，|δψ| < YAW_JITTER_DEG。
参考偏置以 UAV1 为原点，沿参考朝向向右每列 +SPACING_M、向后每排 +SPACING_M。

PX4/模型编号 idx = UAVn - 1（0..14），因此 MAV_SYS_ID = 1..15，与已有
startup_offboard_ego.sh（UAVn ↔ tgt_system n）及端口公式兼容；
模型/命名空间/ID/ID_in_group 均用 idx（iris_0..iris_14）；
端口：mavlink_tcp_port = 4560 + idx，udp_gimbal_port = 13030 + idx。
"""

import math
import os
import random

# ---------- 可编辑参数 ----------
HOME_LAT = 38.4997783         # UAV11 home 纬度（deg，2026-10-22 机载实测）
HOME_LON = 103.2054728        # UAV11 home 经度（deg）
HOME_ALT = 1348.66            # UAV11 home 高程（m，AMSL）
# UAV11 compass_hdg = 326.41°（北=0，顺时针）；Gazebo/ROS ENU yaw 以东=0、逆时针：
# yaw = 90 - compass = 90 - 326.41 = -236.41° ≡ 123.59°。
REF_YAW_DEG = 123.59          # 编队参考朝向（deg），0 = 世界 +x
SPACING_M = 5.0               # 编队参考间距（m）
Z_BASE_M = 0.5                # 生成高度基准（m）
POS_JITTER_M = 0.8            # 水平（x/y）随机偏差上界（m），U(-1, 1) * 该值
Z_JITTER_SCALE = 0.5          # z 轴随机偏差相对 POS_JITTER_M 的缩放
YAW_JITTER_DEG = 12.0         # 偏航随机偏差上界（deg），U(-1, 1) * 该值
SEED = None                   # None = 每次随机；填整数可复现
# --------------------------------

ROWS = 5
COLS = 3
UAV_COUNT = ROWS * COLS

OUT_PATH = os.path.normpath(os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "launch", "multi_uav_ego_15sim.launch"))


def fmt(value):
    return f"{value:.6f}"


def build_launch(seed):
    rng = random.Random(seed)
    yaw = math.radians(REF_YAW_DEG)
    # 参考朝向下的右向量与后向量（世界坐标）
    right = (math.sin(yaw), -math.cos(yaw))
    back = (-math.cos(yaw), -math.sin(yaw))

    out = []
    out.append("<launch>")
    out.append("  <!-- 15 机编队仿真（GUI）：由 bashs/gen_multi_uav_ego_15sim.py 生成，勿手改。")
    out.append(f"       seed={seed}；改参数请编辑脚本后重新生成。")
    out.append("       模型：UAV1..UAV15 -> iris_0..iris_14（ID = ID_in_group = 0..14）")
    out.append(f"       empty world 地理原点：lat={HOME_LAT} lon={HOME_LON} alt={HOME_ALT} m")
    out.append(f"       参考朝向 yaw={REF_YAW_DEG}°（0 = +x），{ROWS} 排 × {COLS} 列，间距 {SPACING_M} m，向右/向后展开：")
    for row in reversed(range(ROWS)):
        names = " ".join(f"UAV{n}" for n in range(row * COLS + 1, (row + 1) * COLS + 1))
        out.append(f"         第{row + 1}排: {names}")
    out.append(f"       摆放误差：x/y ±{POS_JITTER_M} m，z = {Z_BASE_M} + δz（|δz| ≤ {POS_JITTER_M * Z_JITTER_SCALE} m），偏航 ±{YAW_JITTER_DEG}°")
    out.append("       端口：mavlink_tcp_port = 4560 + ID，udp_gimbal_port = 13030 + ID（ID = UAVn-1）")
    out.append("       生成顺序：spawn_model -wait 前一模型，按 iris_0..iris_14 依次插入 Gazebo")
    out.append("       用法（终端 A，仿真 Master 11300）：")
    out.append("         export ROS_MASTER_URI=http://localhost:11300")
    out.append("         export GAZEBO_MASTER_URI=http://localhost:11345")
    out.append("         roslaunch swarm_simulation multi_uav_ego_15sim.launch")
    out.append("       机载层各自 Master 用 startup_offboard_ego.sh 启动（UAV1..15 -> 11311..11325）")
    out.append("       PX4 实例 0..14、MAV_SYS_ID 1..15，与既有启动脚本和端口公式一致。")
    out.append("  -->")
    out.append('  <arg name="world" default="$(find mavlink_sitl_gazebo)/worlds/empty.world"/>')
    out.append('  <arg name="gui" default="true"/>')
    out.append('  <arg name="debug" default="false"/>')
    out.append('  <arg name="verbose" default="false"/>')
    out.append('  <arg name="paused" default="false"/>')
    out.append("")
    out.append('  <arg name="home_lat" default="%s"/>' % HOME_LAT)
    out.append('  <arg name="home_lon" default="%s"/>' % HOME_LON)
    out.append('  <arg name="home_alt" default="%s"/>' % HOME_ALT)
    out.append("  <!-- groundtruth/GPS 插件（Gazebo 进程内）优先读这三个环境变量；")
    out.append("       env 必须写在 include 之前，子 include 才会继承。 -->")
    out.append('  <env name="PX4_HOME_LAT" value="$(arg home_lat)"/>')
    out.append('  <env name="PX4_HOME_LON" value="$(arg home_lon)"/>')
    out.append('  <env name="PX4_HOME_ALT" value="$(arg home_alt)"/>')
    out.append("")
    out.append('  <include file="$(find gazebo_ros)/launch/empty_world.launch">')
    out.append('    <arg name="gui" value="$(arg gui)"/>')
    out.append('    <arg name="world_name" value="$(arg world)"/>')
    out.append('    <arg name="debug" value="$(arg debug)"/>')
    out.append('    <arg name="verbose" value="$(arg verbose)"/>')
    out.append('    <arg name="paused" value="$(arg paused)"/>')
    out.append("  </include>")

    for idx in range(UAV_COUNT):
        row, col = divmod(idx, COLS)
        x_ref = col * SPACING_M * right[0] + row * SPACING_M * back[0]
        y_ref = col * SPACING_M * right[1] + row * SPACING_M * back[1]
        x = x_ref + rng.uniform(-POS_JITTER_M, POS_JITTER_M)
        y = y_ref + rng.uniform(-POS_JITTER_M, POS_JITTER_M)
        z = Z_BASE_M + rng.uniform(-POS_JITTER_M, POS_JITTER_M) * Z_JITTER_SCALE
        spawn_yaw = math.radians(
            REF_YAW_DEG + rng.uniform(-YAW_JITTER_DEG, YAW_JITTER_DEG))

        out.append("")
        out.append(f'  <group ns="iris_{idx}">')
        out.append('    <include file="$(find swarm_simulation)/launch/single_vehicle_spawn_seq.launch">')
        out.append(f'      <arg name="x" value="{fmt(x)}"/><arg name="y" value="{fmt(y)}"/>')
        out.append(f'      <arg name="z" value="{fmt(z)}"/>')
        out.append(f'      <arg name="R" value="0"/><arg name="P" value="0"/><arg name="Y" value="{fmt(spawn_yaw)}"/>')
        out.append('      <arg name="vehicle" value="iris"/><arg name="sdf" value="iris"/>')
        out.append(f'      <arg name="ID" value="{idx}"/><arg name="ID_in_group" value="{idx}"/>')
        out.append(f'      <arg name="mavlink_tcp_port" value="{4560 + idx}"/>')
        out.append(f'      <arg name="udp_gimbal_port" value="{13030 + idx}"/>')
        wait = "" if idx == 0 else f"-wait iris_{idx - 1}"
        out.append(f'      <arg name="wait_for_model" value="{wait}"/>')
        out.append('      <arg name="interactive" value="true"/>')
        out.append("    </include>")
        out.append("  </group>")

    out.append("</launch>")
    return "\n".join(out) + "\n"


def main():
    seed = SEED if SEED is not None else random.randrange(2 ** 32)
    content = build_launch(seed)
    with open(OUT_PATH, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"wrote {OUT_PATH} (seed={seed})")


if __name__ == "__main__":
    main()
