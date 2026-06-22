# EXPECT: fail
# Unbounded-walk fixture: a worker IBC with an empty acceptance array. Without a
# definition of done the walk is unbounded -> the WorkerIBC contract MUST make
# `nickel export` exit non-zero (baseline delta-E0 != 0).
let c = import "../contracts/worker_ibc.ncl" in
(
  {
    id = "PX",
    tier = "worker / opus-class",
    discipline = 'core,
    depends_on = [],
    goal = "Do something, somehow.",
    non_goals = [],
    premises = [],
    delegated = [],
    reserved = [],
    constraints = [],
    context_map = [],
    acceptance = [],
    load_bearing = [],
    plastic = [],
  } | c.Worker
) | c.WorkerIBC
