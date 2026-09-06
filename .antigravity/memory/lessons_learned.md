# Lessons Learned
*Living document of insights gained during development.*
1. Multi-school section ID generation must preserve exact legacy STME string representations (`${year}_${branch}_${div}`) to avoid breaking client-side subscriptions and Firestore references.
2. In multi-school environments, program name substrings can collide (e.g. `B.B.A. LL.B` vs `B.A. LL.B`); always match more specific program patterns first.
3. Law (SOL) canonical section IDs use normalized semester tokens: `Semester V` -> `SemV` (`SOL_3rdYear_BALLB_SemV_A`).
