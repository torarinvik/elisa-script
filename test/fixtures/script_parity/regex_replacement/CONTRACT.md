# C02 Perl-shaped string-regex replacement parity slice

This bounded fixture compares an independent Perl reference with an
Elisascript candidate over replacement behaviors already implemented by the
string-template API: numbered captures, named captures, whole-match
interpolation, sequential zero-width start/end anchor substitutions on one
evolving value, deletion, and global non-overlap.
It also pins the no-match rule: the original input remains unchanged.
An empty input with a zero-width start anchor must terminate and emit its one
replacement.
The exact ordered output is checked against a separate golden and both process
results.

The candidate uses `regex_sub`, `replace_regex`, and `Regex.sub` so their
pattern-first/text-first receiver facades share one observable contract. This
is not callback replacement coverage: `RegexCallback` matcher integration,
effect/error propagation, and callback invocation exactly once per match
remain open under C02. The public-launcher test requires explicit validation
reauthorization, an active RSS guard, and the pinned local compiler; all
fixture sources and the golden are SHA-256 pinned. No runtime result is implied
until that gate is explicitly run.
