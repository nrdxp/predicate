# Apply-contract shim for the refine procedure (D5 / yaml-deposits).
#
# This file evaluates to RefineProcedure — the contract the process gate
# applies externally to a worker YAML deposit:
#
#   nickel export <deposit>.yaml --apply-contract refine_apply.ncl
#
# The deposit is pure-data YAML (no Nickel execution model), so self-binding
# (A-B1) and import-DoS are impossible by construction.  The gate applies the
# contract here, outside the deposit, so footprint-presence and step-grammar
# checks cannot be weakened by the walk.
#
# Imports resolve relative to this file (ledger/contracts/), so no -I flag is
# needed when this file is passed as an absolute path to --apply-contract.
(import "refine_procedure.ncl").RefineProcedure
