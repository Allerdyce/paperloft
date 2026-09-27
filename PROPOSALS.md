# Proposed local phase progression

Pending owner approval requested in chat. Extend the existing local-development exception to permit local phases in order after independent applicable checks pass. Keep acceptance criteria and frozen verifier unchanged; separately report formal gate FAILs caused by deferred prerequisites. Continue baseline integrity checks and append-only locking of accepted test/fixture hashes. Issue no phase-completion tags or release claims while formal gates remain deferred. Complete all formal gates before distribution.

Reason: AGENTS.md requires strict P0-to-P2 order while acceptance-v1 is expressly postponed, so the existing exception permits bootstrap work but leaves progression ambiguous.
