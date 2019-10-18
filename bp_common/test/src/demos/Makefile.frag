BP_DEMOS_C = \
  basic_demo            \
  atomic_queue_demo_2   \
  atomic_queue_demo_4   \
  atomic_queue_demo_8   \
  atomic_queue_demo_16  \
  queue_demo_2          \
  queue_demo_4          \
  queue_demo_8          \
  queue_demo_16         \
  copy_example          \
  trap_demo             \
  atomic_demo           \
  hello_world_atomic    \
	mc_sanity_1           \
	mc_sanity_2           \
	mc_sanity_4           \
	mc_sanity_8           \
	mc_sanity_16

BP_DEMOS_S = \
	simple                \
	uc_simple             \
  hello_world

BP_DEMOS = $(BP_DEMOS_S) $(BP_DEMOS_C)

