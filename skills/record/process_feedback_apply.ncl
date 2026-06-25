# Apply-contract shim for process-feedback YAML instances.
#
# Usage (from the project root, with nickel on PATH):
#   nickel export <file>.yaml --apply-contract skills/record/process_feedback_apply.ncl
#
# The instance file is pure-data YAML (no Nickel execution model) — validated
# externally by this shim. Self-binding and import-DoS are impossible by
# construction (YAML has no execution model).
#
# Imports resolve relative to THIS file's location (skills/record/), so
# process_feedback.ncl is found in the same directory without any -I flag.
(import "process_feedback.ncl").ProcessFeedbackStore
