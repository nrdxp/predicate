# The Control-Theoretic Formalism

The first-principles derivation of the control-theoretic substrate beneath
Predicate's doctrine. If the framework is to be an engineering discipline rather
than a metaphor, its mathematical mapping must be exact. This document separates
the literal mathematical realities from the structural analogies, then extends
the model to the three phenomena the doctrine's *prevention* half already relies
on.

The vocabulary is the one the [README](../../README.md) uses for the substrate —
stochastic walks over $P(\mathbf{S}_{t+1} \mid \mathbf{S}_t)$, the Gibbs-Boltzmann
distribution, phase-space constriction, and closed-loop drive toward $\Delta E
\to 0$. Nothing here imports machinery beyond it; the extension is the *same*
phase-space / attractor-basin operators applied to phenomena the original four
mappings left implicit.

---

## Part 1: First-Principles Scrutiny

The four core mappings, each stated as the critique a skeptic raises and the
rigorous truth that answers it.

### 1. The Markov-chain assumption

* **The critique.** In a classical first-order Markov chain the next state
  depends *only* on the current state. Transformers use self-attention: the next
  token depends on the *entire* context window, not a single predecessor.
* **The rigorous truth.** The formalism holds exactly once the "state" at step
  $t$ is defined not as a single token $x_t$ but as the **entire prefix
  sequence** $\mathbf{S}_t = (x_0, x_1, \dots, x_t)$. Under that definition
  autoregressive generation is a walk across a stochastic transition graph,
  $P(\mathbf{S}_{t+1} \mid \mathbf{S}_t)$ — a high-order process collapsed to
  first-order by absorbing history into the state. The Markov property is
  recovered, not abandoned.

### 2. Temperature and the Boltzmann distribution

* **The rigorous truth.** "Thermal noise" is not an analogy. The map from logits
  $z_i$ to probabilities is precisely the **Gibbs-Boltzmann distribution** of
  statistical mechanics:
  $$P(x_i) = \frac{\exp(z_i / \tau)}{\sum_j \exp(z_j / \tau)}$$
  where $\tau$ is a literal thermodynamic temperature. As $\tau \to 0$ the
  distributional entropy collapses and the system freezes into a deterministic
  local minimum (greedy decoding); as $\tau$ rises, thermal noise lets the
  trajectory traverse local minima at the cost of stochastic drift.

### 3. Entropic contraction vs. phase-space constriction

* **The critique.** Does entropy strictly decrease token by token? No. Local
  token entropy fluctuates — finishing a sentence drops next-token uncertainty to
  near zero, but starting the next one spikes it again.
* **The rigorous truth.** What strictly contracts is not local entropy but the
  **phase-space volume** of valid remaining trajectories. Because the walk cannot
  backtrack, every emitted token is an irreversible constraint that prunes whole
  branches of the trajectory tree. The IBC defines the boundaries of an
  **attractor basin**; once the sequence's momentum falls into that basin the
  degrees of freedom constrict monotonically even while pointwise entropy
  oscillates. Contraction is a property of the trajectory *set*, not of any
  single step.

### 4. Stochastic relaxation vs. closed-loop control

* **The critique.** Is a single generation pass a "relaxation" process? No.
  Relaxation implies bidirectional energy minimization. The inner loop of an LLM
  is an **open-loop stochastic walk**, and because error vectors compound in
  open-loop systems, drift over a long horizon is mathematically inevitable.
* **The rigorous truth.** True stochastic relaxation lives in the **outer loop**.
  When a deterministic evaluator — a compiler, a schema validator, a test runner,
  or a decorrelated reviewer — scores the output, yields an error differential
  $\Delta E$, and the boundary is updated $\mathbf{S}_{k+1} = \mathbf{S}_k \oplus
  \Delta \mathbf{S}_{k+1}$, the system becomes a **closed-loop feedback
  controller** executing derivative-free stochastic optimization toward $\Delta E
  \to 0$. The inner walk drifts; the outer loop is what relaxes.

### The economic axiom — the selection rule the closed loop implies

The four mappings yield one corollary that the doctrine treats as its generating
rule: **no wasted tokens — a hit is cheaper than a miss.** It is not a slogan but
a consequence of mapping 4. Because the inner walk is open-loop, an uncorrected
error vector does not stay fixed — it *compounds*: a miss at step $t$ shifts the
prefix $\mathbf{S}_t$, and every subsequent transition $P(\mathbf{S}_{t+1} \mid
\mathbf{S}_t)$ samples from the displaced distribution, so the cost of a miss grows
super-linearly in the horizon over which it goes undetected. The closed-loop
correction that resolves it, by contrast, costs a bounded $\Delta E$ measurement
plus one boundary update. A token spent *now* — verifying a condition,
re-surfacing a diluted invariant (mapping 5), or searching outward before a
guess — is therefore an investment against a compounding future cost, and the
expected saving is positive exactly when the probability-weighted cost of the
averted miss exceeds the present token spend.

This is why the discipline is *economical*, not merely cautious: every gate,
re-injection, and outward probe in the doctrine is a place where the early,
bounded cost is provably below the compounding cost it forecloses. It also sets
the *limit* on ceremony — a check whose averted-miss cost does not exceed its
token spend is waste in the other direction, the over-ceremony the
[focus-level selector](../../ambient.md#the-focus-level-selector) guards against.
The axiom thus generates both halves of the discipline: spend tokens where a miss
compounds, withhold them where it does not.

**Conclusion.** The four mappings are rigorously validated. This validation is the
*substrate* beneath Predicate's doctrine, not its headline: the
[Verification Dual](../../rules.md) is the discipline a practitioner works in, and
closed-loop stochastic trajectory control is the physics that discipline rests
on. The math earns the doctrine; it does not replace it.

---

## Part 2: The Prevention Extension

Part 1 models a *single walk* and the *outer loop that corrects it* — the
detection-and-correction half of the framework. Three phenomena that the doctrine
already acts on are absent from those four mappings, and each is the *prevention*
half: a force that the IBC alone does not contain, requiring a standing
discipline rather than a corrective pass. Each is derived in the same phase-space
/ attractor-basin language, adding no new mathematics — only lifting the existing
operators onto the structure they already imply.

### 5. Attention-dilution: the basin's hold decays with length

* **The critique.** Part 1 treats the IBC as fixing an attractor basin at $t=0$
  and stops there. But the basin's *grip* is not constant. The boundary condition
  is a finite set of tokens $\mathbf{c}_0 \subset \mathbf{S}_t$; as the prefix
  grows, does its influence on the next token hold?
* **The rigorous truth.** It decays. Self-attention distributes a fixed, normalized
  probability mass — the softmax of the attention logits — across *all* keys in the
  context. At step $t$ that mass is split over $\Theta(t)$ keys, so the average
  attention weight available to any fixed early span, including the IBC tokens
  $\mathbf{c}_0$, falls as the context lengthens. Information-theoretically, the
  mutual information between the boundary condition and the next token,
  $$I(\mathbf{c}_0 ; x_t),$$
  is non-increasing in $t$ absent re-injection: the IBC's share of the conditioning
  signal is diluted by the accumulating prefix. The attractor basin set by the IBC
  at $t=0$ is real, but its *depth as felt at step $t$* — the restoring force pulling
  the walk back toward it — attenuates. Drift is therefore not only the compounding
  of open-loop error (mapping 4); it is also the *fading of the very constraint that
  defines the basin*. The two are distinct failure modes: one accumulates error away
  from a fixed pull, the other weakens the pull itself.
* **The doctrine it grounds — selective re-surfacing.** The corrective operator is
  re-injection: placing the load-bearing invariant *back* into the recent context
  restores $I(\mathbf{c}_0 ; x_t)$, re-deepening the basin at step $t$. This is the
  formal content of "re-surface the invariant selectively" and of the
  [boundary-reconstruction](../../ambient.md#boundary-reconstruction) reflex that
  [rules.md §7](../../rules.md) mandates at the start of every long-horizon step.
  *Selectively* is the load-bearing qualifier: re-injecting everything would
  re-dilute the mass it was meant to concentrate, so only the highest-precedence
  constraints — the Prime Invariants and the active ledger — are re-surfaced. The
  discipline is not redundancy; it is mutual-information maintenance against a
  monotone decay.

### 6. Design-space constriction: stability is a measured curve

* **The critique.** The phase-space-contraction operator of mapping 3 acts on the
  trajectory set of *one walk*. The same operator should act on a larger object —
  the **project's design space** — but the model does not lift it there, and the
  doctrine's `molten`/`stable` flag is declared by hand rather than derived.
* **The rigorous truth.** Lift the operator. Where mapping 3 prunes the set of
  valid *trajectories* as tokens are emitted, mapping a domain prunes the set of
  valid *designs* as constraints are discovered. Each surfaced constraint — an
  invariant, a contract, an unknown-unknown made known — is an irreversible cut
  that contracts the **design basin**, exactly as each emitted token contracts the
  trajectory basin. The project's design phase-space volume $V(n)$ is monotone
  non-increasing in the number $n$ of discovered constraints.
  What matters for maturity is not $V$ but its *rate of contraction* — the
  discrete derivative $V(n{-}1) - V(n)$, i.e. how much basin each newly discovered
  constraint still removes. Early in a domain (**`molten`**) the rate is high:
  every probe surfaces unknown-unknowns that sharply contract the space. As the
  domain is mapped, the supply of undiscovered constraints runs dry, the increments
  shrink, and the contraction rate approaches zero. **`molten` → `stable` is exactly
  that transition** — the rate of new-constraint discovery going to zero, not a date
  or a version number.
* **The doctrine it grounds — the maturity flag as measurement.** This makes the
  [Cutting Imperative's](../../rules.md) maturity flag a *measured property of the
  contraction curve*, not a declared stance. `molten` is the regime where the
  discovery rate is still high, so refactoring and cutting freely is correct: the
  basin is still moving and amend-only would ossify a shape that is still
  contracting. `stable` is the regime where the rate has gone dry, so amend-by-default
  is correct: the basin has settled and each remaining cut must justify itself. The
  flag flips when the curve flattens — a falsifiable reading of the design-space
  derivative, which is why "treating a work-in-progress repository as immutable is a
  defect, not caution" is a statement about the *measured curve*, not a preference.

### 7. Basin-nesting: defeaters as basin-separating moves

* **The critique.** Mappings 3 and 6 each speak of a *single* attractor basin. But
  goals are not flat — an ecosystem goal contains project goals, which contain
  component goals, which contain task goals. The model has no structure for goals
  that are correct locally yet wrong globally.
* **The rigorous truth.** Make the basins **nested**. A goal at each level defines
  an attractor basin, and the basins stand in set containment:
  $$B_{\text{task}} \subset B_{\text{component}} \subset B_{\text{project}} \subset B_{\text{ecosystem}}.$$
  A move is *admissible* at a level when it keeps the walk inside that level's
  basin. Because the basins are nested, a move can satisfy the innermost
  constraint while violating an outer one — it lands inside $B_{\text{task}}$ yet
  outside $B_{\text{project}}$. That is the formal definition of a **defeater**: a
  local move that exits the parent basin while remaining inside the local one,
  $$x \in B_{\text{local}} \;\wedge\; x \notin B_{\text{parent}}.$$
  A locally optimal token sequence — the expedient shortcut, the clever hack, the
  green test bought by weakening the property — can be globally defeating precisely
  because basin membership is not preserved upward under containment. The nesting
  also makes the failure *detectable*: a defeater is exactly a separating witness
  between a child basin and its parent, so verification need only check membership
  against the *parent* boundary, not re-derive the whole goal.
* **The doctrine it grounds — defeaters and strategic escalation.** This is why a
  move that satisfies the immediate task can still be wrong, and why the
  [Strategic Escalation](../../ambient.md#planning-invariants) invariant separates
  *tactical* drift (a move that stays inside the parent basin — record and
  continue) from *strategic* drift (a move that exits it — escalate and halt).
  Tactical-vs-strategic *is* inside-vs-outside-the-parent-basin. A defeater is the
  trigger condition for an `ESCALATION` block: the walk has found a witness that it
  is about to leave the parent basin, and silently absorbing it would optimize a
  child goal at the cost of the goal that contains it.

---

## The Teleological Boundary

The extension formalizes *prevention within a goal structure* — keeping the walk
inside basins whose nesting is given. It does **not**, and cannot, decide whether
the *outermost* basin is the right one. Whether the ecosystem-level goal
$B_{\text{ecosystem}}$ is itself worth pursuing is a teleological question with no
deterministic evaluator: there is no boundary to check membership against, because
that boundary is the thing in question.

This sits deliberately **outside the formalism**. Per the Verification Dual, a
condition with no possible symbolic evaluator is closed by the **adversarial
path** — decorrelated, context-free review, escalating at its strongest to
cross-model [dialectic](../../ambient.md#the-dialectic-principle). The math
governs everything below the outermost basin; the rightness of the outermost goal
is closed by adversarial review, not by phase-space dynamics. Asserting otherwise
would be a pretty model of the wrong thing — the one failure mode the formalism
must not commit.
