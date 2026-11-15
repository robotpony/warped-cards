# Warped Cards

Card game prototypes, specifications and tests.

## Games

| Game | Status | Docs |
|---|---|---|
| Crib Maze (cribbage on a maze, with match turns) | Rules draft 4, match rules r14, mocks | [rules](cribbage/minigames/rules.md), [stats](cribbage/minigames/stats.md), [concept](cribbage/minigames/concept.md), [mocks](cribbage/minigames/mocks/README.md), [ideation](cribbage/minigames/ideation.md) |
| Classic cribbage | Planned | Shares the engine with the variant |

Shared design: [card mock](design/cards/index.html) (renderer in `design/cards/cards.js`).

Tracking: [PLAN.md](PLAN.md) (phases), [TODO.md](TODO.md) (next tasks), [BUGS.md](BUGS.md), [CHANGELOG.md](CHANGELOG.md). Tests: `node --test cribbage/minigames/mocks/`.

Licence: MIT ([LICENSE](LICENSE)).

## Layout

```
<game>/
  <variant>/      specs and ideation for a variant
  engine/         shared rules code (planned)
  sims/           bots and simulation harness (planned)
  tests/          rules tests (planned)
```
