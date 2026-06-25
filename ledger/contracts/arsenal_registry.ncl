# Arsenal registry — the gated, upstream capability-class registry.
#
# Primitive: P-ARSENAL (primitives-spec.md §P-ARSENAL).
# Source:    arsenal-spec.md (the 12 classes, two modes, member lists).
#
# TWO-PURPOSE (primitives-spec.md §P-GROUND K1):
#   FORMAL GATE  — is the chosen member actually registered in the upstream
#                  class? Is a discovery_ref present? Is the class-mode coherent?
#   SUBSTRATE    — the structured Selection fields give a reviewer grip on class,
#                  chosen, available, justification, and discovery provenance as
#                  distinct quality axes, not a single free-text blob.
#
# Two selection modes (arsenal-spec.md §Gap 1):
#   'ordered — members lie on a cost/strength axis; select by `bias`.
#              Class carries: order (Array String, low→high), bias.
#   'match   — members are NOT substitutable; select the apt one by fitness.
#              Class carries: members (Array Member), each with a fitness key.
#
# Membership gate (I-A2): `chosen ∈ class.order` (ordered) or
# `chosen ∈ member names` (match). The registry is upstream and human-approved;
# a `chosen` outside it fails — no hallucinated-tool bypass.
#
# Contracts exported:
#   Member          — one match-class member {name, fitness}
#   OrderedClass    — a class with a cost/strength order
#   MatchClass      — a class with a set of named members
#   CapabilityClass — tagged union: 'ordered OrderedClass | 'match MatchClass
#   Arsenal         — the full registry record with all 12 classes
#   Selection       — a P-GROUND Deposit extended with arsenal-selection fields;
#                     membership gate enforced against the supplied registry
#
# Composition pattern:
#   selection_value | (Selection registry_record class_name_string)
#
# Verification:
#   CONTRACT DEFINITIONS (this file): nickel typecheck
#   INSTANCES / FIXTURES:             nickel export (with -I ledger/contracts)

let deposit = import "deposit.ncl" in

{
  # ── Non-empty string (mirrors deposit.ncl; redeclared locally for clarity) ──
  NonEmptyString = std.contract.from_predicate (fun v =>
    std.is_string v && std.string.length v > 0
  ),

  # ── Member (match-class member) ──────────────────────────────────────────────
  # Each member in a match class carries a fitness key — its declared domain /
  # trigger — so a reviewer can judge whether the selection was apt per member.
  Member = {
    name    | NonEmptyString,   # the member's canonical name
    fitness | NonEmptyString,   # declared applicability (the moment / concern it fits)
  },

  # ── OrderedClass ─────────────────────────────────────────────────────────────
  # Members lie on a cost→strength axis; selection is by bias along that order.
  # `order` lists members low→high (cheapest/weakest first, strongest last).
  # `bias` is the selection rule: 'strongest picks the top available member,
  # 'cheapest_sufficient picks the cheapest that bounds the task.
  OrderedClass = {
    name  | NonEmptyString,
    mode  | [| 'ordered |],
    order | std.contract.from_predicate (fun v =>
              std.is_array v && std.array.length v > 0
            ),                  # non-empty Array String, low→high
    bias  | [| 'strongest, 'cheapest_sufficient |],
    open  | Bool,               # true = runtime extensions admitted (human-approved)
  },

  # ── MatchClass ───────────────────────────────────────────────────────────────
  # Members are NOT substitutable; selection picks the one whose fitness matches
  # the current context. `members` is a seed list (open=true for all current
  # classes — runtime-discovered members may be added via human-approved registry
  # entries, per I-A2).
  MatchClass = {
    name    | NonEmptyString,
    mode    | [| 'match |],
    members | std.contract.from_predicate (fun v =>
                std.is_array v && std.array.length v > 0
              ),                # non-empty Array Member
    open    | Bool,
  },

  # ── Arsenal ──────────────────────────────────────────────────────────────────
  # The full capability-class registry. 12 classes:
  #   4 ordered: repo-search, verification-evaluator, conditioning-surface,
  #              walker-tier
  #   8 match:   execution-workflow, review-lens, design-modeling,
  #              knowledge-acquisition, language-idiom, authoring-style,
  #              harness-tool, project-org-specific
  #
  # Member lists are SEED EXAMPLES (open=true, runtime-discovered). The spec
  # notes that classes 11–12 (harness-tool, project/org-specific) are wholly
  # runtime-populated; 5–10 are open to the user's own skills.
  #
  # A `Selection` deposit draws `chosen` from the gated member set below;
  # a runtime-discovered extension must first appear here (human-approved) or
  # the membership gate rejects it.
  Arsenal = {
    classes | Array _,
    classes = [
      # ── Ordered class 1: repo-search ────────────────────────────────────────
      # Covers the bounding primitive (ls-files) through full structural
      # analysis (repomap / call-graph trace).
      {
        name  = "repo-search",
        mode  = 'ordered,
        order = [
          "ls-files",          # enumerate — the cheapest bounding primitive
          "keyword-grep",      # exact text match
          "regex-grep",        # pattern match
          "fuzzy-search",      # approximate text
          "semantic-search",   # intent-based (grepai search)
          "repomap",           # structural-map — exhaustive architectural review
          "call-graph-trace",  # caller/callee tracing (grepai trace)
        ],
        bias = 'cheapest_sufficient,
        open = true,
      },

      # ── Ordered class 2: verification-evaluator ──────────────────────────────
      # The evaluator hierarchy (rules.md §2 Invariant 1), strongest-last.
      # `review` is the floor for conditions where no deterministic evaluator
      # can exist. Selection by 'strongest (never weaken the evaluator tier).
      {
        name  = "verification-evaluator",
        mode  = 'ordered,
        order = [
          "lint",            # static analysis
          "example-test",    # example-based unit test
          "property-test",   # property / fuzz / metamorphic test
          "type-check",      # type-system verification
          "proof",           # formal proof
          "review",          # decorrelated adversarial review (the review floor)
        ],
        bias = 'strongest,
        open = true,
      },

      # ── Ordered class 3: conditioning-surface ────────────────────────────────
      # How the governing invariants reach the walk. Strongest wins: a
      # system-prompt is the highest-authority injection surface.
      {
        name  = "conditioning-surface",
        mode  = 'ordered,
        order = [
          "prepend",         # prepended context in the user turn
          "rules-file",      # project/org-level rules file (CLAUDE.md / AGENTS.md)
          "system-prompt",   # model system prompt (highest authority)
        ],
        bias = 'strongest,
        open = true,
      },

      # ── Ordered class 4: walker-tier ─────────────────────────────────────────
      # Cheap to expensive; pick the cheapest walker whose capability bounds
      # the task (rules.md §2 Invariant 6, tier economy).
      {
        name  = "walker-tier",
        mode  = 'ordered,
        order = [
          "haiku",           # cheapest; mechanical/retrieval work
          "flash",           # fast middle tier (gemini flash)
          "sonnet",          # capable worker tier
          "opus",            # architect tier; expensive; map + judge
        ],
        bias = 'cheapest_sufficient,
        open = true,
      },

      # ── Match class 5: execution-workflow ────────────────────────────────────
      # The skill whose innermost state machine governs this walk's procedure.
      # Selection is by the MOMENT / DISCIPLINE, not by cost. Each member names
      # the moment it owns.
      {
        name    = "execution-workflow",
        mode    = 'match,
        members = [
          { name = "core",          fitness = "implementing plan steps; TDD state machine with commit gates" },
          { name = "refine",        fitness = "polishing existing artifacts; contraction loop, MBSS sweeps" },
          { name = "boundary",      fitness = "crafting a boundary IBC for an expensive or autonomous walk" },
          { name = "campaign",      fitness = "multi-workstream orchestration; survey → orchestrate → reconcile" },
          { name = "orchestration", fitness = "driving a validated campaign DAG; dispatch/reconcile loop" },
          { name = "doc",           fitness = "authoring technical documentation artifacts" },
          { name = "orient",        fitness = "orienting to a codebase; populating the AGENTS.md anchor" },
        ],
        open = true,
      },

      # ── Match class 6: review-lens ───────────────────────────────────────────
      # The audit skill whose lens fits the concern under review. Members are
      # NOT substitutable — an API-audit lens and a security-audit lens serve
      # different concerns.
      {
        name    = "review-lens",
        mode    = 'match,
        members = [
          { name = "hickey",        fitness = "structural simplicity; decomplecting concerns" },
          { name = "lowy",          fitness = "volatility boundary alignment" },
          { name = "security-audit", fitness = "security concerns; threat modeling; injection risks" },
          { name = "ai-audit",      fitness = "LLM / AI system safety and correctness concerns" },
          { name = "api-audit",     fitness = "public API surface design and stability" },
          { name = "git-review",    fitness = "git history hygiene; commit boundary quality" },
          { name = "doc-audit",     fitness = "documentation link integrity; formatting; headers" },
        ],
        open = true,
      },

      # ── Match class 7: design-modeling ───────────────────────────────────────
      # The modeling skill appropriate to the domain/task. Members address
      # distinct modeling tasks (specification vs. formal model vs. state machine).
      {
        name    = "design-modeling",
        mode    = 'match,
        members = [
          { name = "spec",               fitness = "specifying normative invariants and behavioral contracts" },
          { name = "form",               fitness = "building a formal mathematical model of a domain" },
          { name = "sdma",               fitness = "state-machine-driven modeling and analysis" },
          { name = "formal-foundations", fitness = "deep mathematical foundations; axioms and proofs" },
        ],
        open = true,
      },

      # ── Match class 8: knowledge-acquisition ─────────────────────────────────
      # How missing facts, patterns, or prior art are acquired. Fitness is keyed
      # on what is missing: a known pattern vs. a fact vs. an RFC.
      {
        name    = "knowledge-acquisition",
        mode    = 'match,
        members = [
          { name = "prior-art", fitness = "non-trivial algorithms, patterns, or abstractions; production-grade references" },
          { name = "web-search", fitness = "facts, standards (RFC/spec), or recent developments not in training" },
          { name = "literature", fitness = "academic references; formal theory citations" },
        ],
        open = true,
      },

      # ── Match class 9: language-idiom ────────────────────────────────────────
      # The language-specific skill matching the file type being authored.
      {
        name    = "language-idiom",
        mode    = 'match,
        members = [
          { name = "go",         fitness = "Go source files; Go idioms and toolchain" },
          { name = "rust",       fitness = "Rust source files; ownership, traits, cargo" },
          { name = "python",     fitness = "Python source files; type hints, packaging, tooling" },
          { name = "typescript", fitness = "TypeScript/JavaScript source files; types, build tools" },
          { name = "quarto",     fitness = "Quarto documents; literate programming; pandoc" },
        ],
        open = true,
      },

      # ── Match class 10: authoring-style ──────────────────────────────────────
      # The style skill that fits the OUTPUT GENRE being produced.
      {
        name    = "authoring-style",
        mode    = 'match,
        members = [
          { name = "documentation", fitness = "durable user-facing documentation; long-form explanations" },
          { name = "humanizer",     fitness = "removing machine-prose tells; making text feel authored" },
          { name = "chronicle",     fitness = "narrative chronicles; decision histories; zettelkasten notes" },
        ],
        open = true,
      },

      # ── Match class 11: harness-tool ─────────────────────────────────────────
      # Runtime-discovered harness tools (Read/Edit/Bash/Agent/Web/MCP/...).
      # This class is WHOLLY runtime-populated; the members below are seed
      # examples only. Fitness = the specific capability the tool provides.
      {
        name    = "harness-tool",
        mode    = 'match,
        members = [
          { name = "Read",       fitness = "read a file or resource from the local filesystem" },
          { name = "Edit",       fitness = "make targeted string replacements in a local file" },
          { name = "Bash",       fitness = "execute a shell command" },
          { name = "Agent",      fitness = "launch a sub-agent for complex or parallel sub-tasks" },
          { name = "WebFetch",   fitness = "fetch the content of a URL" },
          { name = "WebSearch",  fitness = "run a web search query" },
          { name = "MCP",        fitness = "invoke a tool provided by a connected MCP server" },
          { name = "ToolSearch", fitness = "load deferred tool schemas before invocation" },
        ],
        open = true,
      },

      # ── Match class 12: project-org-specific ─────────────────────────────────
      # The OPEN slot: project- or org-specific tools, discoverable only at
      # condition-time. Human-approved entries land here; the walk may not
      # self-author members into this class without registry amendment.
      {
        name    = "project-org-specific",
        mode    = 'match,
        members = [
          { name = "grepai",  fitness = "semantic code search and call-graph tracing via grepai" },
          { name = "agy",     fitness = "agent harness: multi-model dispatch via agy CLI" },
        ],
        open = true,
      },
    ],
  },

  # ── Selection ────────────────────────────────────────────────────────────────
  # A Selection IS a P-GROUND Deposit (composes deposit.ncl Deposit base) with
  # additional arsenal-selection fields.
  #
  # A Selection is produced by applying this contract OVER an Arsenal instance
  # via the `make_selection` combinator below — the registry is the authority,
  # not a self-declared field.
  #
  # Fields beyond the Deposit base:
  #   class_name     — which class was selected from (must match a registered name)
  #   chosen         — the selected member (gated: must ∈ registered class members)
  #   available      — the members discovered as available at condition-time
  #   discovery_ref  — a DepositRef to the DISCOVERY deposit (provenance; I-A3)
  #   justification  — why this member was selected (the reviewer's quality axis)
  #
  # TWO-PURPOSE (K1):
  #   FORMAL    class_name, chosen, available, discovery_ref must be present +
  #             non-empty; chosen must be in the registered class member set.
  #   SUBSTRATE each field is a distinct reviewer question: "right class?",
  #             "in registry?", "was discovery run?", "is justification substantive?"
  #
  # Membership gate (I-A2):
  #   ordered class  → chosen ∈ class.order
  #   match class    → chosen ∈ (std.array.map .name class.members)
  #
  # Usage:
  #   selection_value | (make_selection arsenal_record "class-name")
  #
  # The base Deposit shape (id, step, evidence, cites, refs) is enforced by
  # extracting the five base fields into a sub-record and applying
  # `deposit.Deposit` to that projection. Nickel record contracts are closed by
  # default, so we cannot apply `Deposit` to the full Selection value (which
  # carries additional fields). Projecting first gives us the Deposit shape-
  # check without triggering "extra fields" rejection.
  make_selection = fun arsenal class_name =>
    std.contract.custom (fun label value =>
      # 1. Enforce the Deposit base shape: project the five base fields.
      let base_projection = {
        id       = value.id,
        step     = value.step,
        evidence = value.evidence,
        cites    = value.cites,
        refs     = value.refs,
      } in
      let _base = std.deep_seq (base_projection | deposit.Deposit) null in

      # 2. Locate the registered class by name.
      let matching =
        std.array.filter
          (fun c => c.name == class_name)
          arsenal.classes
      in

      if std.array.length matching == 0 then
        'Error { message =
          "Selection references unknown class \"" ++ class_name ++ "\": not in registry"
        }
      else
        let cls = std.array.first matching in

        # 3. Resolve the registered member set for the class.
        let registered_members =
          if cls.mode == 'ordered then
            cls.order
          else
            std.array.map (fun m => m.name) cls.members
        in

        # 4. Check `chosen` field presence and non-emptiness.
        let chosen = value.chosen in
        let _chosen_ne =
          std.deep_seq (chosen | NonEmptyString) null
        in

        # 5. Membership gate (I-A2): chosen ∈ registered members.
        let member_ok = std.array.elem chosen registered_members in

        # 6. Check `available` field (non-empty array of strings).
        let available = value.available in
        let _avail_ok =
          std.deep_seq (
            std.contract.apply
              (std.contract.from_predicate (fun v =>
                std.is_array v && std.array.length v > 0
              ))
              label
              available
          ) null
        in

        # 7. Check `discovery_ref` (a DepositRef — target + role).
        let _dref = std.deep_seq (value.discovery_ref | deposit.DepositRef) null in

        # 8. Check `justification` non-empty.
        let _just = std.deep_seq (value.justification | NonEmptyString) null in

        # Force all structural checks before the membership verdict.
        std.seq _base (
          std.seq _chosen_ne (
            std.seq _avail_ok (
              std.seq _dref (
                std.seq _just (
                  if !member_ok then
                    'Error { message =
                      "Selection.chosen \"" ++ chosen
                      ++ "\" is not a registered member of class \""
                      ++ class_name ++ "\""
                    }
                  else
                    'Ok value
                )
              )
            )
          )
        )
    ),
}
