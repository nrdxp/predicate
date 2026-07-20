# conditioning/constitution.ncl — predicate's project constitution, single-sourced in
# the CONDITIONING layer as a Nickel value conforming to council.ncl's `Constitution`
# (seats + decision_types + delegation). This is LAW / system-prompt, NOT a ledger data
# instance and NOT AGENTS.md.
#
# ONE source, TWO consumers read THIS file:
#   * conditioning/compose.ncl RENDERS it into the composer's system prompt, so the live
#     conductor is conditioned with the very council law it conducts.
#   * ledger/contracts/council_apply.ncl IMPORTS it as the constitution threaded into
#     DecisionLedger, so the production merge-consent gate (council_consent.sh) validates
#     real decision-ledgers against predicate's OWN law.
#
# It imports NOTHING — it is the independent first-class SOURCE. The fixture
# ledger/fixtures/council/constitution.yaml mirrors THIS in spirit for the law's
# self-contained unit tests; neither derives from the other (no coupling, either way).
#
# Values are native Nickel enum TAGS ('standing, 'single, …), so the record conforms to
# `Constitution` directly — no YAML-string lift is needed (council_apply.ncl's
# coerce_constitution is idempotent on tags, so the same apply serves both this value
# and the YAML fixture unchanged).
#
# Ownership (matches the reconciled council): head-ratified dag-amendment ->
# architect; dispatch / convene / lifecycle / dag-structure -> composer (the
# conductor); reconcile-accept + merge -> maintainer (per-node acceptance lives in
# the merge gate — the ONLY seat a routine node's reconcile requires; other seats
# and guests join a node only when the composer convenes them for an exceptional
# one); residue -> auditor; taste-fork / bar -> human (the head); close ->
# architect under FULL machine consensus AND head ratification (the whole bench,
# guests included, convenes only there).
{
  seats = [
    { id = "architect",  role = "boundary / goal / strategy",       domain = "boundary",        standing = 'standing },
    { id = "composer",   role = "execution structure / scheduling", domain = "execution",       standing = 'standing, conductor = true },
    { id = "maintainer", role = "lead developer / lead maintainer",  domain = "merge",           standing = 'standing },
    { id = "auditor",    role = "process + residue",                 domain = "process",         standing = 'standing },
    { id = "human",      role = "head / ultimate arbiter",           domain = "taste / release", standing = 'standing, head = true },
  ],
  decision_types = [
    "boundary-design",
    "dag-structure",
    "dag-amendment",
    "reconcile-accept",
    "dispatch",
    "convene",
    "lifecycle",
    "classification",
    "merge",
    "taste-fork",
    "residue",
    "bar",
    "close",
  ],
  delegation = [
    { decision_type = "boundary-design",  owner = "architect",  required_assent = 'single },
    { decision_type = "dag-structure",    owner = "composer",   required_assent = 'single },
    # head-ratified: architect owns it, but the head (human) MUST ratify.
    { decision_type = "dag-amendment",    owner = "architect",  required_assent = 'single, must_assent = ["human"] },
    # Per-node acceptance folds into the merge gate: for a routine node the
    # maintainer's affirmative consent IS the accept; the architect joins only
    # when convened for an exceptional (load-bearing) node.
    { decision_type = "reconcile-accept", owner = "maintainer", required_assent = 'single },
    { decision_type = "dispatch",         owner = "composer",   required_assent = 'single },
    { decision_type = "convene",          owner = "composer",   required_assent = 'single },
    { decision_type = "lifecycle",        owner = "composer",   required_assent = 'single },
    { decision_type = "classification",   owner = "architect",  required_assent = 'subset, quorum = 2 },
    # explicit merge-consent: the maintainer's recorded assent is mandatory.
    { decision_type = "merge",            owner = "maintainer", required_assent = 'single, must_assent = ["maintainer"] },
    { decision_type = "taste-fork",       owner = "human",      required_assent = 'human },
    { decision_type = "residue",          owner = "auditor",    required_assent = 'single },
    { decision_type = "bar",              owner = "human",      required_assent = 'human },
    # terminal: FULL machine consensus ('full excludes the head) AND head ratification.
    { decision_type = "close",            owner = "architect",  required_assent = 'full, must_assent = ["human"] },
  ],
}
