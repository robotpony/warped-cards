// Writes dice.json from the reference dice (mocks/dice.js). Every port MUST
// reproduce these values exactly. Rerun only when engine.md › Dice changes,
// and say so in the commit. Run: node cribbage/minigames/fixtures/make-dice.js
const fs = require("fs");
const path = require("path");
const D = require("../mocks/dice.js");

const seeds = ["0", "1", "20261114", "18446744073709551615"];
const streams = ["deal", "reveal", "board", "prize", "bot.1"];
const weights = [["card", 90], ["scoring", 9], ["item", 1]];

const cases = [];
for (const seed of seeds) for (const name of streams) {
  const raw = D.stream(BigInt(seed), name);
  const first = Array.from({ length: 4 }, () => raw.next64().toString());
  const s = D.stream(BigInt(seed), name);
  const below = [52, 10, 7, 1, 100].map(n => s.below(n, "test"));
  const s2 = D.stream(BigInt(seed), name);
  const picks = Array.from({ length: 8 }, () => s2.pick(weights, "test"));
  const s3 = D.stream(BigInt(seed), name);
  const shuffle = s3.shuffle(Array.from({ length: 52 }, (_, i) => i), "test");
  cases.push({ seed, stream: name, streamSeed: (BigInt.asUintN(64, BigInt(seed)) ^ D.fnv1a64(name)).toString(), first64: first, below: { n: [52, 10, 7, 1, 100], values: below }, pick: picks, shuffle52: shuffle });
}

const out = {
  version: 1,
  about: "Reference values for engine.md › Dice. 64-bit numbers are decimal strings. Each part starts a fresh stream from the seed: first64 is the first four raw outputs; below draws below each n in turn; pick is eight weighted picks from the weights; shuffle52 is a Fisher-Yates shuffle of 0 to 51.",
  vectors: {
    fnv1a64: [["", "14695981039346656037"], ["a", D.fnv1a64("a").toString()], ["deal", D.fnv1a64("deal").toString()]],
    splitmix64: { seed: "1234567", first: (() => { const n = D.splitmix64(1234567n); return [n(), n(), n()].map(String); })() }
  },
  weights,
  cases,
};
fs.writeFileSync(path.join(__dirname, "dice.json"), JSON.stringify(out, null, 2).replace(/\[\s*([^\[\]{}]*?)\s*\]/g, (_, inner) => "[" + inner.replace(/\s*\n\s*/g, " ") + "]") + "\n");
console.log("wrote", cases.length, "cases");
