cmake_minimum_required(VERSION 3.0.2)
project(swarm_simulation)

# 仅仿真环境 launch（Gazebo world + PX4 SITL spawn），不包含 MAVROS/planner/
# executor/GCS/bridge（implementation_plan_26083018 §4.1）。gazebo_ros/px4/
# mavlink_sitl_gazebo 为纯 launch 运行时依赖（package.xml exec_depend），
# 非 catkin package，无需 find_package。
find_package(catkin REQUIRED)

catkin_package()

install(DIRECTORY launch/
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}/launch
)
