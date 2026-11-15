// Crib Maze: reference dice, exactly as engine.md › Dice describes them (2026-11-14).
//
// Named streams: each stream's seed is the game seed XOR the FNV-1a 64 hash of
// its name; SplitMix64 fills xoshiro256**'s state; draws below n use Lemire's
// method with rejection. This file writes fixtures/dice.json (run
// `node cribbage/minigames/fixtures/make-dice.js`) and is what every port
// checks itself against. Plain script, BigInt only, no modules.

(function () {
  const window = typeof globalThis.window !== "undefined" ? globalThis.window : globalThis;
  const M64 = (1n << 64n) - 1n;
  const rotl = (x, k) => ((x << BigInt(k)) | (x >> BigInt(64 - k))) & M64;

  function fnv1a64(text) {
    let h = 0xcbf29ce484222325n;
    for (const b of new TextEncoder().encode(text)) {
      h ^= BigInt(b);
      h = (h * 0x100000001b3n) & M64;
    }
    return h;
  }

  function splitmix64(seed) {
    let s = BigInt.asUintN(64, BigInt(seed));
    return function next() {
      s = (s + 0x9e3779b97f4a7c15n) & M64;
      let z = s;
      z = ((z ^ (z >> 30n)) * 0xbf58476d1ce4e5b9n) & M64;
      z = ((z ^ (z >> 27n)) * 0x94d049bb133111ebn) & M64;
      return z ^ (z >> 31n);
    };
  }

  // One named stream. rolls collects { stream, purpose, n, value } for every draw.
  function stream(gameSeed, name, rolls) {
    const sm = splitmix64(BigInt.asUintN(64, BigInt(gameSeed)) ^ fnv1a64(name));
    const s = [sm(), sm(), sm(), sm()];
    function next64() {
      const result = (rotl((s[1] * 5n) & M64, 7) * 9n) & M64;
      const t = (s[1] << 17n) & M64;
      s[2] ^= s[0]; s[3] ^= s[1]; s[1] ^= s[2]; s[0] ^= s[3];
      s[2] ^= t; s[3] = rotl(s[3], 45);
      return result;
    }
    // An integer from 0 to n − 1, every value equally likely (Lemire, with rejection).
    function below(n, purpose) {
      const bn = BigInt(n);
      if (bn < 1n) throw new Error("below(n) needs n >= 1");
      let m = next64() * bn, low = m & M64;
      if (low < bn) {
        const t = ((1n << 64n) - bn) % bn;
        while (low < t) { m = next64() * bn; low = m & M64; }
      }
      const value = Number(m >> 64n);
      if (rolls) rolls.push({ stream: name, purpose, n, value });
      return value;
    }
    // weights: [[key, weight], ...] in config order. Returns the key.
    function pick(weights, purpose) {
      const total = weights.reduce((a, [, w]) => a + w, 0);
      const d = below(total, purpose);
      let run = 0;
      for (const [key, w] of weights) { run += w; if (d < run) return key; }
      throw new Error("unreachable");
    }
    // Fisher-Yates from the end, in place. One roll per swap step.
    function shuffle(list, purpose) {
      for (let i = list.length - 1; i >= 1; i--) {
        const j = below(i + 1, purpose);
        [list[i], list[j]] = [list[j], list[i]];
      }
      return list;
    }
    return { next64, below, pick, shuffle };
  }

  const api = { fnv1a64, splitmix64, stream };
  if (typeof module !== "undefined") module.exports = api;
  window.WarpedDice = api;
})();
