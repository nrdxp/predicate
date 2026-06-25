# EXPECT: pass
# Positive control: validates the process-feedback seed instances against
# ProcessFeedbackStore.
# Exercises: non-empty string enforcement, Kind enum (both amendment and
# improvement kinds), multi-item store, id uniqueness (4 distinct ids).
let c = import "../../skills/record/process_feedback.ncl" in
(import "process_feedback_seed.yaml") | c.ProcessFeedbackStore
