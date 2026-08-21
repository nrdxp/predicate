# conditioning/core.ncl
#
# THE BEHAVIORAL LAW — the always-on, full-replacement system prompt content.
#
# A single top-level Nickel String, self-contained (no contract imports outside
# this directory), so it is portable and injectable verbatim by `compose.ncl`
# (docs/conditioning-layer.md §The injection-rule contracts). This is the
# COMPLETE coherent law that REPLACES the harness default behavioral block
# (Claude Code output style, keep-coding-instructions:false). It is generated from
# rules.md / ambient.md / the promoted constitution + engineering skills, but is
# the always-on surface itself — those sources demote to by-moment reference.
#
# Calibration (docs/conditioning-layer.md §The invariant-core): PRINCIPLES are
# always-on, PROCEDURES are
# by-moment. Every promoted principle that binds EVERY walker regardless of role
# or discipline earns a place here; role-specific deltas live in a persona overlay
# and detailed procedures stay routed-by-moment as skills. Over-inclusion of
# procedure silences the persona's focus — but under-inclusion of a binding
# principle leaves a coverage gap the disabled default would have filled.
#
# Clause identity: the law is composed from conditioning/core_clauses.ncl, an
# ordered array of addressable clause records (stable id + text), not typed
# inline as one undifferentiated string. A `##` section with no numbered/bulleted
# sub-rules is itself one clause (`leaf`); a section whose sub-rules are each
# independently addressable (`group`) contributes one clause per sub-rule and is
# a container, not a clause itself — 18 leaf clauses + 39 grouped sub-rules = 57
# addressable clauses total. Every join point (heading/intro/list-separator/outro)
# is DATA on the block, not inferred, so restructuring the source never perturbs
# a byte of the rendered law below. See core_clauses.ncl for the block/clause
# shapes and for `nickel export --format json 'clause_ids'`-style enumeration.
#
# `render_*` below are ascribed `Dyn -> String` and cast each field they touch
# with `| <Type>` at the point of use, and the whole file closes with `: String`
# so this file typechecks standalone. That local proof does NOT cross the
# import boundary, though: Nickel gives `import "core.ncl"` static type `Dyn`
# from any OTHER file's perspective whenever this file's top-level term is
# anything but a bare literal (a plain `let`-chain infers Dyn, regardless of
# internal ascriptions) — true here now that the render is composed rather
# than one literal string. compose.ncl accordingly binds `core_text` via the
# runtime contract `(import "core.ncl") | String`, not a static `:` ascription
# — see the comment there for the two-line diff this cost.
#
# Export: `nickel export --format text conditioning/core.ncl` → the prose below.

let data = import "core_clauses.ncl" in

let render_group : Dyn -> String = fun b =>
  let items_text =
    std.string.join
      (b.sep | String)
      (std.array.map (fun c => (c.text | String)) (b.clauses | Array Dyn))
  in
  let segs =
    [ (b.heading | String) ]
    @ (b.intro | Array String)
    @ [items_text]
    @ (b.outro | Array String)
  in
  std.string.join "\n\n" segs
in

let render_block : Dyn -> String = fun b =>
  if (b.kind | String) == "leaf" then
    std.string.join "\n\n" [ (b.heading | String), (b.body | String) ]
  else
    render_group b
in

(
  (data.preamble | String)
  ++ "\n\n"
  ++ std.string.join "\n\n" (std.array.map render_block (data.blocks | Array Dyn))
) : String
