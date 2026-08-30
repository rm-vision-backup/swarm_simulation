# swarm_simulation

Gazebo/PX4 SITL **仿真环境层**：只负责多机仿真世界的启动（spawn iris 模型），
不包含 MAVROS、planner、executor、GCS 或 bridge。机载/地面站链路分别由
`swarm_uav_executor`（`uav_offboard_ego.launch` / `startup_offboard_ego.sh`）和
`tcp_to_ros` / `swarm_topology_bridge` 负责。

> 迁移自 `safe_valley_exp`（implementation_plan_26083018 §4.1）。原包仅保留
> 仿真 launch 于此，原包其余职责已迁入 `swarm_uav_executor` 后删除。

## Launch

| launch | 说明 |
|---|---|
| `multi_uav_ego_15sim.launch` | 15 机编队仿真（GUI，`gui:=false` 无头）：UAV1..UAV15 -> iris_0..iris_14，Gazebo Master 11300/11345 |
| `multi_uav_ego_4sim.launch` | 4 机快速调试（GUI）：UAV1..UAV4 -> iris_0..iris_3 |
| `multi_uav_sim.launch` | 通用 4 机仿真（GUI） |
| `multi_uav_sim_headless.launch` | 通用 4 机无头仿真（同 `multi_uav_sim` 拓扑） |

用法（终端 A，仿真环境由外部指令提供）：

```bash
cd /home/ub20tg/catkin_swarm6-2
source /opt/ros/noetic/setup.bash
source devel/setup.bash
source /home/ub20tg/PX4_Firmware/Tools/setup_gazebo.bash \
  /home/ub20tg/PX4_Firmware /home/ub20tg/PX4_Firmware/build/px4_sitl_default
export ROS_PACKAGE_PATH="$ROS_PACKAGE_PATH:/home/ub20tg/PX4_Firmware:/home/ub20tg/PX4_Firmware/Tools/sitl_gazebo"
export ROS_HOME=/home/ub20tg/catkin_swarm6-2/.ros_home
export ROS_LOG_DIR=/home/ub20tg/catkin_swarm6-2/.ros_home/log
mkdir -p "$ROS_LOG_DIR"
export ROS_MASTER_URI=http://localhost:11300
export ROS_HOSTNAME=localhost
export GAZEBO_MASTER_URI=http://localhost:11345
roslaunch swarm_simulation multi_uav_ego_15sim.launch   # 或加 gui:=false
```

- PX4/Gazebo 运行环境通过上述 `source`/`export` 外部指令提供，**不**在
  `swarm_simulation` 的 package.xml 声明（与历史 `safe_valley_exp` 包一致，
  仅 launch、无 node）；`rosdep` 只解析本包自身依赖。
- 无头自主测试约定使用 `gui:=false`（避免 GUI 依赖，便于连续回归）。
- 机载层各自 Master 用 `bash src/swarm_uav_executor/scripts/startup_offboard_ego.sh`
  启动（UAV1..UAV15 -> 11311..11325）。

## 运行依赖（环境外部提供，非本包 rosdep 依赖）

本包仅含 launch 文件，无 node、无 C++/Python 依赖。`rosdep check` 只检查
`catkin` 构建工具。运行时所需环境由启动流程外部指令提供（见上文"用法"）：

- `gazebo_ros`（empty_world）：经 `source setup_gazebo.bash` 加载
- `px4`（`single_vehicle_spawn_xtd.launch`，SITL 实例）：经
  `source setup_gazebo.bash` + `export ROS_PACKAGE_PATH` 加载
- `mavlink_sitl_gazebo`（默认 empty.world）：同上
