# The finalized council constitution instance (the static, per-project law).
# Corrected ownership: reconcile-accept + head-ratified dag-amendment -> architect;
# dispatch / convene (guest-summon) / lifecycle -> composer; merge -> maintainer
# (with explicit merge-consent); bar -> 'human. Validated by c.Constitution.
{
  seats = [
    { id = "architect",  role = "boundary / goal / strategy",        domain = "boundary",      standing = 'standing },
    { id = "composer",   role = "execution structure / scheduling",  domain = "execution",     standing = 'standing },
    { id = "maintainer", role = "lead developer / lead maintainer",   domain = "merge",         standing = 'standing },
    { id = "auditor",    role = "process + residue",                  domain = "process",       standing = 'standing },
    { id = "human",      role = "head / ultimate arbiter",            domain = "taste / release", standing = 'standing, head = true },
  ],
  decision_types = [
    "boundary-design", "dag-structure", "dag-amendment", "reconcile-accept",
    "dispatch", "convene", "lifecycle", "classification", "merge",
    "taste-fork", "residue", "bar", "close",
  ],
  delegation = [
    { decision_type = "boundary-design", owner = "architect",  required_assent = 'single },
    { decision_type = "dag-structure",   owner = "composer",   required_assent = 'single },
    # head-ratified: architect owns it, but the head (human) MUST ratify.
    { decision_type = "dag-amendment",   owner = "architect",  required_assent = 'single, must_assent = ["human"] },
    { decision_type = "reconcile-accept", owner = "architect", required_assent = 'single },
    { decision_type = "dispatch",        owner = "composer",   required_assent = 'single },
    { decision_type = "convene",         owner = "composer",   required_assent = 'single },
    { decision_type = "lifecycle",       owner = "composer",   required_assent = 'single },
    { decision_type = "classification",  owner = "architect",  required_assent = 'subset, quorum = 2 },
    # explicit merge-consent: maintainer's recorded assent is mandatory.
    { decision_type = "merge",           owner = "maintainer", required_assent = 'single, must_assent = ["maintainer"] },
    { decision_type = "taste-fork",      owner = "human",      required_assent = 'human },
    { decision_type = "residue",         owner = "auditor",    required_assent = 'single },
    { decision_type = "bar",             owner = "human",      required_assent = 'human },
    # terminal: full MACHINE consensus ('full excludes the head) AND head ratification.
    { decision_type = "close",           owner = "architect",  required_assent = 'full, must_assent = ["human"] },
  ],
}
