# Where Correction Ends

Every system that stores claims and later learns some of them are wrong has
the same problem: getting the correction to travel as far as the error did.
No field that has studied this problem at scale has solved it. Not truth
maintenance systems, not belief revision, not ontology curation, not
scientific publishing, not incident reporting. Where a field had the formal
apparatus to prove something about the problem, it proved that solving it
in general is impossible or intractable. Where a field built real,
funded infrastructure to catch it in practice, the infrastructure catches a
small minority of cases and has stayed flat for decades.

That is the old, well-documented part. What is new is the rate: language
models now generate and re-state claims fast enough that an unpropagated
correction stops being a slow, tolerable failure and starts being the
default state of the system. What is newest, and least proven, is a
possible way out — not a fix to the propagation problem, but a change to
the kind of artifact that needs correcting in the first place. This piece
lays out all three, and is explicit throughout about which parts are
measured and which are argued.

## The shape shows up wherever it's been checked

Truth maintenance systems, built in AI in the late 1970s to let a reasoner
retract a belief and have every conclusion drawn from it retract
automatically, ran into their own limits early: naive dependency-tracking
schemes that stay complete are exponential in the number of retractions
they've absorbed, because a system's justification structure grows with its
history and every retraction has to walk that structure.

Belief revision theory — the AGM framework, named for Alchourrón, Gärdenfors,
and Makinson — sits one level up: instead of a specific algorithm, it asks
what a *rational* way to shrink or revise a set of beliefs would even look
like. Gärdenfors' own triviality result shows that a natural, independently
plausible way of pairing revision to conditional reasoning collapses into
inconsistency once you make both precise. And when later work tried to carry
AGM's contraction operation over to the ontologies used in modern knowledge
bases, the operation turned out to be uncomputable outside a narrow class of
logics, and the general problem of repairing an inconsistent ontology to be
NP-hard or worse, even in lightweight description logics built to be
efficient. The theory doesn't fail to specify what correction should do. It
succeeds at specifying it precisely enough to show the general case can't be
done.

Where researchers instead measured how well an existing, working, funded
system performs the same job, the numbers are consistently low. Hospital and
aviation near-miss reporting systems are the most heavily studied instance:
self-reporting has been measured to surface on the order of five percent of
actual safety events, and independent audits of hospital incident-reporting
systems have found underreporting running as high as the 50–96% range
depending on event type — meaning capture rates from the single digits up to
roughly a fifth of what actually happened. These are not neglected systems.
Incident reporting has decades of regulatory backing, dedicated staff, and
legal reporting mandates behind it, and it still misses most of what it
exists to catch.

The pattern that connects both halves: **every measured rate here comes from
a human institution.** No model is involved in citation review, incident
reporting, or ontology curation. The failure to propagate a correction is
not something language models introduced. It predates them by decades and
shows up in systems run entirely by people trying, with real incentive, to
get it right.

## The sharpest instrument: what happens when you personally e-mail the author

The clearest test of where the propagation problem actually lives comes from
scientific publishing, and it isolates the question better than any of the
infrastructure numbers above, because it removes two candidate explanations
at once.

Avenell, Bolland, Gamble, and Grey ran a randomized trial, published in
*Accountability in Research* (DOI
[10.1080/08989621.2022.2082290](https://doi.org/10.1080/08989621.2022.2082290)),
that took 88 systematic reviews and clinical guidelines citing 27 retracted
clinical trials and personally e-mailed the citing authors — some with
co-authors also copied, some with the journal editor also copied — to tell
them the trial they had cited was retracted. 86 authors were successfully
reached by e-mail. 51% of them replied. At one year, **9 of those 86** had
resulted in a published formal correction.

Three things have to be said about this number, because it is easy to
overstate:

1. **9 of 86, not the "89%" figure sometimes quoted for this trial.** That
   higher figure comes from a citing paper's own arithmetic on a different
   base, not from Avenell's reported result, and any relay of it that
   doesn't trace back to the trial itself should be treated as unreliable.
2. **The cohort is not "retracted research" in general.** All 27 retracted
   trials trace to a single research-fraud cluster in osteoporosis research
   (work by Yoshihiro Sato and Jun Iwamoto, most of it retracted between
   2016 and 2019). A sentence that generalizes this trial's result to
   authors and retracted work broadly is overstating what was tested.
3. **This document is relying on the abstract, not the full text.** The
   full article was not reachable through the publisher, its DOI redirect,
   a text-extraction proxy, the Internet Archive, or CORE — all returned
   access errors despite the article being indexed as open access. A
   secondary source reports 8 published corrections rather than 9; that
   one-count discrepancy is unresolved here.

What survives those three qualifications, and is the actual point: just
over half of directly, personally notified authors replied to the e-mail,
and the great majority of them still did not produce a correction. That
result does real work, because it rules out the two most obvious
explanations for low correction rates. It isn't that nobody knew — the
authors were told, individually, by name. It isn't that nobody read the
notice — over half replied. Whatever holds correction back in this case, it
sits downstream of both detection and notification.

## What's new: the rate, not the shape

The propagation ceiling above predates any of this era's models by decades.
What has changed is the volume and speed of claim-generation. A 2026 study
of multi-agent language-model pipelines (arXiv:2608.14588, "The
Hallucination Snowball") tracked injected errors through a four-stage
financial-analysis pipeline and found that detectability collapses as an
error gets re-expressed: a model's ability to catch a planted error fell
from 72.0% when it first appeared to 50.9% by the fourth stage of
re-statement, and 23.7% of injected errors survived completely undetected
into the final output — even though every one of them had been individually
detectable at the point it was first introduced. The claims were the same
claims. Restating them in a new form, each time, cost detectability.

Put the two results together and the concern sharpens. A slow, human-paced
system that fails to propagate a correction 80–95% of the time is a serious
and long-standing problem. A system that can generate and re-express claims
orders of magnitude faster, while inheriting the same underlying failure to
propagate a correction, turns an occasional loss into the default outcome —
more claims get made, and each one gets re-expressed sooner, before a
correction anywhere upstream has had a chance to catch it.

## What isn't proven: a possible escape, not a result

Here the piece has to change register, because everything to this point has
been read or measured, and everything past this point is argument.

The hypothesis: the fields surveyed above were pinned to their 5–20%
ceiling by the *medium* they corrected in, not only by the difficulty of
the correction problem itself. A published paper cannot be recomputed —
correcting it means writing and distributing a second document and hoping
readers of the first one see it. A citation, once made, leaves no machine
trace back to its target's current status. If that's right, the ceiling
measured across six literatures is a property of hand-authored,
non-recomputable artifacts, not a hard limit on correction as such — and a
system whose derived artifacts can be *recomputed* from their sources,
rather than hand-maintained after the fact, is not obviously bound by the
same ceiling.

That is a hypothesis with its reasoning exposed, not a finding. Nothing has
been built at scale that tests it. There is no measured correction rate for
a recomputation-based system to compare against the 5–20% figure above.

The one piece of grounding available for this idea is formal, not
empirical, and it should be read as exactly that. This document's author
has produced a machine-checked formal model in the Lean proof assistant
(*Factoring Trust*, [github.com/nrdxp/factoring-trust](https://github.com/nrdxp/factoring-trust))
that treats retraction as *omission plus recomputation*: a claim is
retracted by removing it from the set of currently-held evidence and
re-deriving whatever depended on it, rather than by chasing down every
consumer of the original claim. Inside that model, this is complete and
free of any residual bookkeeping cost, for the precise reason that nothing
derived is stored — there is nothing downstream to go find and fix, because
"downstream" is recomputed on demand rather than kept around to go stale.
That is a proof about a model of the mechanism. It is not evidence that any
real system built this way achieves anything close to it, and it says
nothing about the cost, adoption, or failure modes of building one.

## What this document actually rests on

- **Measured, and read directly:** the incident-reporting capture-rate
  studies cited above, and the Hallucination Snowball propagation numbers.
- **Measured, but read only in abstract, with one unresolved secondary
  discrepancy:** the Avenell trial's central number — 9 of 86 authors
  producing a correction after direct, successful notification.
- **An aggregate across fields, not a single measurement:** the "5–20%
  across six literatures" figure this document leans on in the section
  above. It summarizes a survey rather than one study. Three of those six
  fields — incident reporting, ontology-repair intractability, and
  citation correction — were checked against their own sources while
  writing this; the remaining three carry the survey's authority and were
  not independently re-audited here. Readers weighing the hypothesis in the
  previous section should know that the number it argues against is a
  synthesis.
- **A real, citable formal result, but about a model rather than a
  built system:** the Factoring Trust omission-plus-recomputation
  treatment of retraction.
- **Argument, not measurement, and the least established claim in this
  document:** that non-recomputable media, rather than correction itself,
  is what pinned prior fields to their ceiling — and that a recomputable
  medium can do better. No system has been built or measured against this
  claim. It is stated as a hypothesis because that is what it is.

The structure — correction failing to travel as far as the claim it
corrects — is old. The rate at which uncorrected claims now get produced and
re-stated is new. The idea that recomputable artifacts might not inherit
the old ceiling is newer still, and, unlike the other two claims in this
document, unproven.
