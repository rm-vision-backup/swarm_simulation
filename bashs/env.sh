#!/bin/bash
# bashs 单轮整套 15 机 SITL 测试公共环境
# （正式化自 .tmp/headless_test/env.sh，已验证编排 2026-08/09）
# 日志统一到工作空间 .ros_home/log/headless_test；临时 pid/日志不写 /tmp。
set -u
# 路径不写死某个用户的 home：WS 由本文件位置推导（bashs → 包 → src → 工作空间根），
# PX4_ROOT 默认 $HOME/PX4_Firmware、可用环境变量覆盖（本文件被 source，故用 BASH_SOURCE）。
export WS=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
export PX4_ROOT=${PX4_ROOT:-$HOME/PX4_Firmware}
export PX4_BUILD="$PX4_ROOT/build/px4_sitl_default"
export ROS_HOME="$WS/.ros_home"
export ROS_LOG_DIR="$WS/.ros_home/log"
export HLOG="$ROS_LOG_DIR/headless_test"
export LIBGL_ALWAYS_SOFTWARE=1
mkdir -p "$HLOG"
# source 期间临时关掉 -u（L5 的 `set -u` 契约不变，source 后立刻恢复）：ROS noetic 的
# profile.d/1.ros_distro.sh:3 直接读未定义的 $ROS_DISTRO，nounset 下是**致命错** →
# 本文件被调用方 source 时会把调用方一起带走（2026-09-14 实测：干净 env 下
# `source ./env.sh` = exit 127；本文件被 cleanup/phases/round_prepare_15sitl/status
# 四处 source，从 ROS-less 的 shell（ssh/cron/包装 bash/新终端）起一轮会死在 source
# 这行，连 round 末尾的 cleanup 都跑不到）。PX4 那行读 $ROS_PACKAGE_PATH，同段处理。
set +u
# shellcheck source=/dev/null
source /opt/ros/noetic/setup.bash
# shellcheck source=/dev/null
source "$WS/devel/setup.bash"
source "$PX4_ROOT/Tools/setup_gazebo.bash" "$PX4_ROOT" "$PX4_BUILD" >/dev/null 2>&1
set -u
export ROS_PACKAGE_PATH="$ROS_PACKAGE_PATH:$PX4_ROOT:$PX4_ROOT/Tools/sitl_gazebo"
