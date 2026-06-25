# Authorization predicate (C10, D-DUP). The ONE Nickel home for the path-
# containment logic the campaign's authority gate runs — "not in the IBC ->
# not authorized" made mechanical, and the surface-vs-surface collision test
# the surface-exceed protocol routes on.
#
# Why this file exists: the containment predicate USED to live in two languages
# at once — `dag.ncl`'s `DagNoConflict` carried `token_contains`/`tokens_overlap`
# inline, and `authorized.py` re-implemented the same logic as `covers`/
# `tokens_collide`. One invariant, two implementations, is drift surface (Hickey:
# complected). This module is the single definition both consumers reference:
# `dag.ncl` imports `tokens_overlap` for its conflict gate, and `authorized.py`
# delegates its containment decisions here via a one-shot `nickel export`.
#
# SCOPE (the honest seam): path-CONTAINMENT only — exact match and directory
# subtree prefixing, the predicate Nickel expresses cleanly. Shell-glob matching
# (`templates/*.md`) is NOT here: it is fnmatch's job, the one irreducible
# authorization-time concern that stays in `authorized.py` as the named fallback
# (architecture.md, gate-locus: "fnmatch glob is the one honest Nickel-fallback").
# A surface token carrying a glob metacharacter is inert under these predicates
# (plain string prefixing, no regex), exactly as it was inline in `dag.ncl`.
{
  # starts_with prefix s: does `s` begin with `prefix` (byte-prefix, no regex).
  starts_with = fun prefix s =>
    let lp = std.string.length prefix in
    std.string.length s >= lp && std.string.substring 0 lp s == prefix,

  # dir_prefix t: the directory form of a token — guaranteed trailing "/".
  # A token names a directory subtree addressed by this prefix.
  dir_prefix = fun t =>
    if std.string.length t > 0
       && std.string.substring (std.string.length t - 1) (std.string.length t) t == "/"
    then t
    else t ++ "/",

  # token_contains t1 t2: does subtree-token t1 path-contain t2? True when they
  # are byte-equal, or t2 begins with t1's directory prefix. Plain prefixing —
  # glob metacharacters in a token are inert here (the glob concern is fnmatch's,
  # handled in authorized.py).
  token_contains = fun t1 t2 =>
    t1 == t2 || starts_with (dir_prefix t1) t2,

  # tokens_overlap t1 t2: bidirectional containment — the surface-vs-surface
  # collision test. "docs/" overlaps "docs/x.md" (a directory token contains
  # files beneath it). Used by dag.ncl's DagNoConflict and by authorized.py's
  # collision-check (its containment branch; glob handled separately in Python).
  tokens_overlap = fun t1 t2 =>
    token_contains t1 t2 || token_contains t2 t1,

  # covers surface path: does a file_surface ENTRY cover a concrete changed path?
  # The surface-vs-concrete-path test the authorization gate runs. An empty
  # surface covers nothing; otherwise exact match or directory-prefix. The glob
  # branch (any of *?[ in surface) is NOT decided here — authorized.py layers
  # fnmatch over a false verdict from this predicate.
  covers = fun surface path =>
    surface != "" && (surface == path || starts_with (dir_prefix surface) path),
}
