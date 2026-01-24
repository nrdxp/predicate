---
name: "AI Audit Workflow"
description: "Auditing AI-generated code for common issues"
trigger: "/ai-audit"
---

Standard Operating Procedure: AI-Generated Code Audit Workflow

1. Strategic Foundations: The Post-Generative Audit Paradigm

Traditional Static Analysis Security Testing (SAST) is fundamentally insufficient for the challenges posed by Large Language Model (LLM) outputs. While SAST tools effectively identify known vulnerability signatures, they are blind to "synthetic artifacts"—code blocks that are syntactically flawless but logically "hollow." Strategic auditing must recognize that AI-generated code is characterized by lower structural complexity and lexical diversity than human-written code (Cotroneo et al.). Models prioritize "plausibility" and pattern replication over architectural intent, often resulting in repetitive, shallow logic that satisfies unit tests while failing in production environments.

This Standard Operating Procedure (SOP) enforces the Principle of Zero Trust for Synthetic Code. Auditors must treat every AI-generated line as a high-risk external contribution. The objective is to move beyond simple syntax validation into a deep inspection of structural integrity and logical depth.

Securing the logic layer is the first step in neutralizing the risks of automated generation.

2. Layer 1: The Inefficiency Taxonomy & ODC Framework

As established by Abbassi et al., LLMs prioritize the statistical likelihood of token sequences over algorithmic optimization. This creates a "Taxonomy of Inefficiencies" that leads to massive technical debt. Auditors must expand their search radius upon detecting any failure: research indicates a 0.74 correlation (co-occurrence) between General Logic failures and broader Readability/Maintainability issues.

Mandatory Inspection Protocol: Orthogonal Defect Classification (ODC)

The following steps utilize the ODC framework to standardize audit metrics across all generated components.

ODC Category Technical Trigger The AI-ism (Per Abbassi et al.) Mandatory Remediation
Algorithm Benchmark Requirement: Check prime number divisibility logic. Flag iterations up to n instead of \sqrt{n}. Inefficient Iterative Block: Overly broad initialization/stopping conditions. Narrow loop constraints; implement early stopping to reduce compute cycles.
Algorithm Audit algorithmic complexity. Flag O(n^2) logic (e.g., Insertion Sort) where O(n \log n) is industry standard. Sub-optimal Complexity: Priority of "plausible" patterns over optimized algorithms. Replace brute-force logic with standard libraries or optimized algorithms.
Assignment Scan for used-before-assignment errors or identifiers that overwrite built-ins (e.g., dict = {}). Shadowing & Bloat: Misuse of variable binding and lexical scope. Rename shadowed variables; ensure proper initialization before call sites.
Interface Detect protected-access violations (accessing \_internal members outside class scope). Structural Incoherence: Difficulty generating coherent, contextually integrated class hierarchies. Enforce proper encapsulation; refactor to public APIs or internalize logic.
Checking Identify functions passing "happy path" tests but lacking try/except or null checks. Partially Wrong Logic: Failure to address edge cases (CWE-754) despite passing core prompts. Mandate comprehensive input validation and exception traceability.
Maintainability Scan for "Unnecessary Else" statements after a return or break. Defensive Bloat: Unnecessarily complex control flows that increase surface form without value. Flatten conditional logic; remove redundant blocks to reduce cyclomatic complexity.

Architectural Impact: The "So What?"

Inefficiencies in synthetic code directly inflate cloud compute costs and maintenance overhead. Auditors must recognize that AI code is logically simpler and more repetitive than human code; any deviation into complexity without a clear performance gain is a diagnostic marker of model failure.

Logic validation is moot if the underlying supply chain is poisoned by phantom dependencies.

3. Layer 2: Slopsquatting & Dependency Verification Protocol

"Slopsquatting" is a critical supply chain risk where attackers register "Phantom Dependencies"—hallucinated package names suggested by LLMs. Statistics from Snyk/Lanyado research indicate that GPT-4 hallucinates packages ~20% of the time, while Gemini reaches 64.5%.

Mandatory Verification Steps

1. Registry Cross-Referencing: Every import must be verified against official registries (npm, PyPI). Warning: High download counts are not a proxy for safety; the "huggingface-cli" phantom package received 30,000 downloads despite being an empty research artifact.
2. Version Hallucination Audit: Flag any version requirement that does not exist in official history (e.g., pandas==2.5.0 or tensorflow==3.2.1).
3. Ecosystem Integrity Check: Reject "Cross-Ecosystem Borrowing." Flag Python code attempting to use JS-style scoped naming (e.g., @utils/helper).

Remediation Directive: Slopsquatting IF a phantom dependency or unverified package is detected: Nuke and rebuild the component. Do not attempt to "fix" the import. Re-generate the module using only organization-approved, security-vetted libraries.

Dependency integrity ensures the foundation is solid before evaluating the "Transformer Cadence."

4. Layer 3: Stylistic Signature & "Transformer Cadence" Detection

AI-generated code exhibits "Verbosity Drift" and a specific rhythm known as "Transformer Cadence." As noted by Reddit and Bohr researchers, these stylistic markers often correlate with underlying logic gaps.

Diagnostic Checklist

- [ ] Marker A: Robotic Documentation: Flag comments that explain what is happening (# increment x by 1) rather than why the logic exists.
- [ ] Marker B: Defensive Bloat: Identify redundant null checks or wrappers that increase "surface form" while masking shallow logical depth.
- [ ] Marker C: Context Collapse: Detect "loops of code modification"—where complexity increases across iterations without resolving the root bug.

Context Collapse Remediation

Mandate a "Stop and Restart" threshold: If code complexity (NLOC/CCN) increases over three iterations without resolving the primary defect, discard the current session. The model has entered a state of "Constraint Attention" diversion; start a fresh context to clear hallucination loops.

Final adherence is determined by the model's ability to respect negative constraints.

5. Layer 4: Instruction Adherence & Reasoning Failure Audit

Amazon Science defines the "Curse of Instructions," where failure rates increase exponentially with multiple constraints. Crucially, explicit Chain-of-Thought (CoT) reasoning diverts focus; the model becomes so engrossed in its own reasoning trace that it neglects simple constraints (e.g., "Do not use the requests library").

Audit Procedure: Constraint Attention

1. Task 1: Constraint Mapping: Map all negative constraints and formatting rules from the original prompt.
2. Task 2: Attention Analysis: Audit the reasoning trace. Flag instances where the model acknowledges a constraint in its "thinking" but violates it in the final code block.

Final Remediation Directive: If significant adherence failure is detected under high-constraint prompts, Mandate Classifier-Selective Reasoning. Bypass the LLM's internal CoT in favor of an external constraint-validation classifier to recover performance on instruction-heavy tasks.

---

6. Workflow Finalization & Audit Report Template

Critical Risk Scorecard

Layer ODC Mapping Focus Area High-Risk Indicator
Layer 1 Algorithm/Assignment Logic & Performance O(n^2) complexity; prime check benchmarks failed.
Layer 2 Interface Security & Dependencies Hallucinated packages (20%+ risk); version phantoms.
Layer 3 Function/Class Stylistic Signature Robotic comments; "Defensive Bloat" hiding shallow logic.
Layer 4 Checking Instruction Adherence Violations of negative constraints; CoT-driven neglect.

Audit Report Command

The Auditor must present the final report to the Software Architect prioritizing remediability. Provide a clear Pass/Fail for each layer. High-risk artifacts must be rejected immediately. Highlight where the code lacks "lexical diversity" or "structural depth," and provide the specific ODC-mapped remediation steps required for production readiness.
