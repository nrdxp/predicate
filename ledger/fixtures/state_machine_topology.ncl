# Positive-control fixture for state_machine.ncl (R1 topology gate).
#
# Applies the StateMachine contract to the full L0+L1 transition table exported
# from state_machine.ncl. `nickel export` of THIS file is the topology gate —
# an import error or a contract violation makes nickel exit non-zero.
#
# Usage:
#   nix run nixpkgs#nickel -- export -I ledger/contracts ledger/fixtures/state_machine_topology.ncl
#
# Note: state_machine.ncl itself is verified with `nickel typecheck`
# (contract definitions, not exportable values). This fixture is the
# exportable instance — the pattern mirrors deposit.ncl and its consumers.
let sm = import "../contracts/state_machine.ncl" in
(sm.topology | sm.StateMachine)
