# Warped Cards

Card game prototypes, specifications and tests.

## Games

| Game | Status | Docs |
|---|---|---|
| Crib Maze (cribbage on a maze, with match turns) | Rules draft 4, match rules r15, mocks | [rules](cribbage/minigames/rules.md), [stats](cribbage/minigames/stats.md), [concept](cribbage/minigames/concept.md), [engine](cribbage/minigames/engine.md), [mocks](cribbage/minigames/mocks/README.md), [ideation](cribbage/minigames/ideation.md) |
| Classic cribbage | Planned | Shares the engine with the variant |

Shared design: [card mock](design/cards/index.html) (renderer in `design/cards/cards.js`).

App design: [ARCHITECTURE.md](ARCHITECTURE.md) (Swift app, engine, tracking, effects), [LIBRARIES.md](LIBRARIES.md) (tools and libraries).

Tracking: [PLAN.md](PLAN.md) (phases), [TODO.md](TODO.md) (next tasks), [BUGS.md](BUGS.md), [CHANGELOG.md](CHANGELOG.md). Tests: `node --test cribbage/minigames/mocks/`.

Licence: MIT ([LICENSE](LICENSE)).

## Layout

```
<game>/
  <variant>/      specs, ideation, mocks and playtests for a variant
    fixtures/     rules fixtures shared by the mocks and Swift (planned)
swift/            engine, tracking, effects, simulator and app (planned)
design/           shared design mocks (cards)
```
