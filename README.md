# Warped Cards

Card game prototypes, specifications and tests.

## Games

| Game | Status | Docs |
|---|---|---|
| Crib Maze (cribbage on a maze, with match turns) | Rules draft 2 | [rules](cribbage/minigames/rules.md), [stats](cribbage/minigames/stats.md), [concept](cribbage/minigames/concept.md), [ideation](cribbage/minigames/ideation.md) |
| Classic cribbage | Planned | Shares the engine with the variant |

## Layout

```
<game>/
  <variant>/      specs and ideation for a variant
  engine/         shared rules code (planned)
  sims/           bots and simulation harness (planned)
  tests/          rules tests (planned)
```
