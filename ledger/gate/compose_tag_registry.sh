# compose_tag_registry.sh — the shared "materialize a project-local tag
# registry beside the law" idiom.
#
# ledger/contracts/tag_registry.ncl ships EMPTY
# (.ledger/tech-debt/tag-registry-ships-predicate-vocabulary.yaml): a
# consuming project's own vocabulary lives at <ledger-root>/tag_registry.ncl,
# and Nickel's import is static, so entry.ncl cannot conditionally resolve a
# file that may or may not exist. Every caller that wants a project's own
# vocabulary admitted must therefore compose it in BEFORE nickel runs — a
# scratch copy of the law, materialized beside the resolved registry (the
# same copy-the-law idiom test_entry.sh's own mutation cases already use to
# vary the law). Two production entrypoints need this
# (entries_integrity.sh, topic_query.sh); this file is the one place the
# idiom lives, sourced by both, rather than two diverging copies of it.
#
# Not executable on its own — sourced, then called as a function.
#
# Usage:
#   source ".../compose_tag_registry.sh"
#   compose_tag_registry <law-dir> <registry-file-or-empty> <out-dir>
#
# <law-dir>       ledger/contracts — where entry.ncl, entry_apply.ncl,
#                 entries_query.ncl, and entries_query_apply.ncl live.
# <registry-file> the project's own tag_registry.ncl, already resolved by
#                 the caller (each caller's own discovery differs: a
#                 multi-path corpus argument vs. one dedicated ledger-root
#                 variable, so discovery stays the caller's job). Pass ""
#                 when no project registry was found.
# <out-dir>       the caller's own scratch directory; its lifetime and
#                 cleanup stay the caller's (this function never creates or
#                 removes a temp dir of its own).
#
# Sets COMPOSED_APPLY and COMPOSED_QUERY to the resulting entry_apply.ncl /
# entries_query_apply.ncl paths: <out-dir>'s composed copies when a registry
# file was given and exists, <law-dir>'s own files (importing the plugin's
# empty default) otherwise. COMPOSED_QUERY is always the bare Views contract
# (entries_query_apply.ncl), never the law record (entries_query.ncl) --
# `nickel export --apply-contract` needs a bare contract, and pointing it at
# the law record instead fails with "extra fields" against every field the
# law carries beyond Views.
compose_tag_registry() {
  local law_dir="$1" registry_file="$2" out_dir="$3"
  if [ -n "$registry_file" ] && [ -f "$registry_file" ]; then
    mkdir -p "$out_dir"
    cp "$law_dir/entry.ncl" "$out_dir/entry.ncl"
    cp "$law_dir/entry_apply.ncl" "$out_dir/entry_apply.ncl"
    cp "$law_dir/entries_query.ncl" "$out_dir/entries_query.ncl"
    cp "$law_dir/entries_query_apply.ncl" "$out_dir/entries_query_apply.ncl"
    cp "$registry_file" "$out_dir/tag_registry.ncl"
    COMPOSED_APPLY="$out_dir/entry_apply.ncl"
    COMPOSED_QUERY="$out_dir/entries_query_apply.ncl"
  else
    COMPOSED_APPLY="$law_dir/entry_apply.ncl"
    COMPOSED_QUERY="$law_dir/entries_query_apply.ncl"
  fi
}
