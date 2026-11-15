# To do

Small next tasks. Bigger work is in [PLAN.md](PLAN.md).

## Crib Maze

- [x] Fold Bruce's answers to the 13 match turn and maze questions into the docs (`cribbage/minigames/concept.md` › Decisions)
- [ ] Playtest the match turn on rules r15 (edge power multipliers) and save the runs (`cribbage/minigames/playtests/`)
- [ ] Clear runs saved before rules versioning (they show as `r?`)
- [x] Wire the score breakdown into the match turn (`mocks/match-turn.html`)
- [x] Pause the timer during the score breakdown
- [x] Name the bonus tally: pips
- [x] Decide suit ties for match-turn steps (`rules.md` › Suit gates)
- [ ] Notes toward the maze walk mini game (`concept.md` › The maze walk)
- [ ] Shop mock: what you pay with now that pips are gone, and selling jokers and special jokers between rounds
- [ ] Tune bot levels so medium scores like a person, from playtest runs
- [x] Match turn begin effect: cards fall into place from the deck (`concept.md` › Transitions and effects)
- [x] Match turn end effects: board cleared (with its bonus) vs not (`concept.md` › Transitions and effects)
- [x] Show each set's suit, or "no suit" on ties, in the match turn and score breakdown (`rules.md` › Suit gates)
- [ ] Make clearing the board hard enough to feel big, once human playtests show how often a person clears it (`concept.md` › Learnings)
- [ ] Jokers and extra cards: design the title and blank card prizes, how many jokers a round can have, each special joker type's rules, and what happens when one is dealt or cut (`rules.md` › Jokers and extra cards)
- [ ] Jokers: design items (amber's rare outcome) and settle how many joker draws a game has (`mocks/README.md` › Jokers v1)
- [ ] Show the amber and teal jokers, title card and blank card on the card design page (`design/cards/index.html`)
- [ ] Measure "no suit" ties in human playtests (share of steps, by bot level and by person) before changing the tie rule (`rules.md` › Suit gates)
- [ ] Score breakdown: keep the tally panel off the set when a set spans the top and bottom rows
- [ ] Graph playtest runs by rules version (`cribbage/minigames/stats.md` › Mock playtests)
- [ ] Gather maze inspiration before the maze mock

## Repo

- [x] Licence: MIT
- [ ] Put the version in the Swift app once it exists (`MARKETING_VERSION`), in step with the changelog
