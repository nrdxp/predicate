# Shared sub-procedure registry (primitives-spec.md §P-COMPOSE).
#
# The UPSTREAM, human-approved, GATED enum of shared sub-procedures a skill's
# procedure step may `invoke`. Same gating property as the arsenal registry and
# the required-step set (the recurring K3/F-REQ doctrine): the set that JUDGES a
# walk lives upstream and is never self-authored by the walk. A skill's procedure
# authors `steps` only; it cannot add a member to this registry to legitimise an
# invocation. An `invoke.class` outside this set FAILS the contract — that is the
# machine-detectable no-spaghetti gate (I-C3): a skill reaching for an
# unregistered cross-procedure is a forbidden state, caught structurally.
#
# Why a registry and not a free string: a free-text class is trivially "non-empty"
# and so passes any presence check while asserting nothing. Pinning the class to a
# closed, upstream-curated set is what makes "no spaghetti" a real gate rather than
# a hope — the same reason `dag.ncl`'s `discipline` is an enum, not a String.
#
# Contracts exported:
#   members      — the canonical list of registered sub-procedure class names
#   SubProcedure — a contract admitting only a registered class name
#
# Verification:
#   CONTRACT DEFINITIONS (this file): nickel typecheck
#   MEMBERSHIP CHECK: composed into procedure.ncl's Procedure contract (I-C3)
{
  # The gated upstream set. Adding a member is a privileged, human-approved edit
  # to THIS file — never an act of the walk being judged. The shipped members are
  # the universal cross-procedures named in the spec; project extensions enter
  # ONLY here, under human approval (the un-self-authored property).
  members = [
    "discovery",          # the outward-environment / outward-world enumeration sub-procedure
    "adversarial-review", # decorrelated context-free review (the Verification Dual's soft path)
    "prior-art",          # production-reference + literature search (rules.md §4.6)
  ],

  # A contract admitting only a registered class name. Used by procedure.ncl to
  # gate every `invoke.class`. `std.array.elem` over the upstream `members` is the
  # whole gate — an unregistered class is rejected EAGERLY when the field is forced
  # under the per-step `std.deep_seq` in the Procedure contract.
  SubProcedure = std.contract.from_predicate (fun value =>
    std.is_string value && std.array.elem value members
  ),
}
