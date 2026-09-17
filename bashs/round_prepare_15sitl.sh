#!/bin/bash
# =============================================================================
# round_prepare_15sitl.sh —— 15 机 PX4 SITL 整套单轮测试（正式化入库版本）
#
# 来源：.tmp/headless_test/{run,cleanup,status,env}.sh + .tmp/scripts/run_15uav_prepare.sh
#       （该编排在 2026-08-30 ~ 2026-09-07 的 prepare 验收中使用，见
#        src/tcp_to_ros/test_records/test_record_26090722.md 等记录）
# 阶段：clean -> .ros_home 隔离 -> sim(15 px4) -> onboard(15) -> gcs bridge ->
#        gcs backend+标定 -> tcp(39001) -> takeoff(15) -> task prepare -> RESULT
#        -> （失败轮复制飞行记录到 .ros_home_roundN）-> 无条件 cleanup
#
# 用法：
#   bash src/swarm_simulation/bashs/round_prepare_15sitl.sh \
#       --round 1 [--task prepare] [--timeout-s 150] [--keep-ros-home-on-fail 1]
#
# 约定（遵循项目规范）：
#   - 所有日志留在工作区：.ros_home（含每机 PX4 sitl_iris_* ulog）、
#     .ros_home/log/headless_test（阶段日志）、.tmp/logs（机载层）。
#   - 每轮从干净 .ros_home 开始：完成后 .ros_home 只含本轮飞行记录；
#     失败轮（默认）把 .ros_home 整目录复制为 .ros_home_roundN，不占用默认 .ros_home。
#   - 退出码：0=prepare SUCCESS；1=失败（此时可能已生成 .ros_home_roundN）；2=用法错。
#   - 中断或失败任何阶段都会在脚本末尾执行 cleanup（进程/端口清 0）。
# =============================================================================
set -u
cd "$(dirname "$0")"
WS=/home/yjq/catkin_swarm6-2

ROUND=""
TASK="prepare"
TIMEOUT_S=150
KEEP_ON_FAIL=1

while [ "$#" -gt 0 ]; do
  case "$1" in
    --round) ROUND="${2:-}"; shift 2 ;;
    --task) TASK="${2:-prepare}"; shift 2 ;;
    --timeout-s) TIMEOUT_S="${2:-150}"; shift 2 ;;
    --keep-ros-home-on-fail) KEEP_ON_FAIL="${2:-1}"; shift 2 ;;
    -h|--help) sed -n '1,30p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# 每轮隔离：清空 .ros_home（保留目录），本脚本的 HLOG 重建于 .ros_home/log/headless_test
rm -rf "$WS/.ros_home" && mkdir -p "$WS/.ros_home/log"
source ./env.sh

cleanup() { bash ./cleanup.sh >/dev/null 2>&1 || true; }
trap cleanup EXIT

log "===== [1] pre-clean ====="
bash ./cleanup.sh >/dev/null 2>&1 || true
sleep 2

log "===== [2] sim (15 px4 + gazebo, master 11300) ====="
bash ./phases.sh sim
SIM_OK=0
for i in $(seq 1 60); do
  G=$(timeout 5 env ROS_MASTER_URI=http://localhost:11300 rosnode list 2>/dev/null | grep -c '/gazebo' || true)
  P=$(pgrep -x px4 | wc -l)
  log "sim gazebo=$G px4=$P/15 (t=${i}x5s)"
  [ "$G" -ge 1 ] && [ "$P" -ge 15 ] && SIM_OK=1 && break
  sleep 5
done
[ "$SIM_OK" = 1 ] || { log "FAIL sim not ready"; exit 1; }

log "===== [3] onboard (15 masters 11311..11325) ====="
bash ./phases.sh onboard
ON_OK=0
for i in $(seq 1 45); do
  R=$(grep -c '^ready UAV' "$HLOG/02_onboard.log" 2>/dev/null || true)
  log "onboard ready=$R/15 (t=${i}x5s)"
  [ "$R" -ge 15 ] && ON_OK=1 && break
  sleep 5
done
[ "$ON_OK" = 1 ] || { log "FAIL onboard not ready"; exit 1; }

log "===== [4] gcs bridge -> backend + calibration (master 11310) ====="
bash ./phases.sh gcs_bridge_only
sleep 5
GCS_OK=0
for i in $(seq 1 20); do
  M=$(timeout 3 env ROS_MASTER_URI=http://localhost:11310 rosnode list >/dev/null 2>&1 && echo 1 || echo 0)
  [ "$M" = "1" ] && GCS_OK=1 && break
  sleep 3
done
[ "$GCS_OK" = 1 ] || { log "FAIL gcs master 11310 not up"; exit 1; }
sleep 5
bash ./phases.sh gcs_backend_only
CAL_OK=0
for i in $(seq 1 40); do
  C=$(timeout 3 env ROS_MASTER_URI=http://localhost:11310 rosparam get /group_a/calibration_ready 2>/dev/null || echo false)
  log "gcs calibration_ready=$C (t=${i}x5s)"
  [ "$C" = "true" ] && CAL_OK=1 && break
  sleep 5
done
[ "$CAL_OK" = 1 ] || { log "FAIL calibration not ready"; exit 1; }

log "===== [5] tcp server (39001) ====="
bash ./phases.sh tcp
TCP_OK=0
for i in $(seq 1 12); do
  L=$(ss -ltn 2>/dev/null | grep -c ':39001 ' || true)
  log "tcp listening=$L (t=${i}x3s)"
  [ "$L" -ge 1 ] && TCP_OK=1 && break
  sleep 3
done
[ "$TCP_OK" = 1 ] || { log "FAIL tcp not listening"; exit 1; }

log "===== [6] takeoff (15) ====="
bash ./phases.sh takeoff
TK_OK=0
for i in $(seq 1 40); do
  K=$(grep -c '成功 15/15' "$HLOG/06_takeoff.log" 2>/dev/null || true)
  log "takeoff ok=$K (t=${i}x5s)"
  [ "$K" -ge 1 ] && TK_OK=1 && break
  sleep 5
done
[ "$TK_OK" = 1 ] || { log "FAIL takeoff"; exit 1; }

log "===== [7] task ${TASK} (timeout ${TIMEOUT_S}s) ====="
bash ./phases.sh task "$TASK" "$TIMEOUT_S"
TPID=$(cat "$HLOG/07_task_${TASK}.pid" 2>/dev/null || echo 0)
for i in $(seq 1 90); do
  if [ -n "$TPID" ] && [ "$TPID" != 0 ] && ! kill -0 "$TPID" 2>/dev/null; then
    break
  fi
  sleep 5
done

log "===== RESULT ====="
RESULT_JSON="$HLOG/07_task_${TASK}.log"
STATUS=""
FAILED=""
TICKS=""
if python3 - "$RESULT_JSON" <<'PY'
import json,sys
try:
    d = json.load(open(sys.argv[1], encoding='utf-8'))
except Exception as exc:
    print("PARSE_ERROR %s" % exc); sys.exit(2)
print("status=%s failed=%s ticks=%s" % (d.get("status"), d.get("failed_robot_ids"), d.get("ticks")))
PY
then
  :  # 上面的解析已打印一行概要
else
  tail -8 "$RESULT_JSON"
fi

# 退出码判定：task 输出 JSON status==SUCCESS 为通过
FINAL_STATUS=$(python3 - "$RESULT_JSON" 2>/dev/null <<'PY'
import json,sys
try: print(json.load(open(sys.argv[1], encoding='utf-8')).get("status",""))
except Exception: print("")
PY
)

if [ "$FINAL_STATUS" = "SUCCESS" ]; then
  log "ROUND RESULT: SUCCESS"
  exit 0
fi

log "ROUND RESULT: FAILURE/UNKNOWN (task=${TASK})"
# 失败轮保留飞行记录：把本轮 .ros_home（sitl ulog 等）复制到 .ros_home_roundN
if [ "$KEEP_ON_FAIL" = 1 ] && [ -n "$ROUND" ]; then
  DEST="$WS/.ros_home_round${ROUND}"
  rm -rf "$DEST"
  cp -a "$WS/.ros_home" "$DEST"
  log "kept flight records -> $DEST"
fi
exit 1
