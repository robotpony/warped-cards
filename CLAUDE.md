# Warped Cards

Card game prototypes, specs and tests. One session acts as project commander; other agents are spawned for focused work.

## Conventions

- Specs are Markdown, written per the `product-writing` skill (Canadian English, RFC 2119 words, no em-dashes, ASCII sketches without box-drawing). Write simply, for people first.
- Each game keeps a concept doc (intent, fun, decisions, plan), a rules doc (player-facing) and a stats doc. Record decisions with dates in the concept doc and keep the rules doc in step.
- One standard 52-card deck unless a spec says otherwise.
- Classic cribbage rule wording lives in `~/projects/utilities/scorekeep/docs/rules/cribbage.md` (owned by the SCOREKEEP session). Reference it, don't copy it. Don't invent classic scoring rules that conflict with it; ask SCOREKEEP.
- Balance claims need simulation numbers, not estimates.
- Order of work: rules and mocks (design track) alongside engine spec, Python engine and simulator (engine track). Swift comes last, built from the specs.
- Games are 1 human vs 1 or 2 bots. Bots are game features, not just test tools.
