// Warped Cards, neon look: card renderer (v1, 2026-11-14).
//
// Dropped for card faces on 2026-11-14 (Bruce: too hard to read). Card faces stay
// design/cards/cards.js on the neon table. Still current here: the markers (pill,
// keptStar) and tray buttons (itemIcon). The faces are kept for reference.
//
// The same API as design/cards/cards.js (window.WarpedCards), so a mock switches look
// by loading neon-core.js and this file instead: front, back, special, extra, joker,
// plus the neon extras (prize faces, item icons, markers). Cards are width-driven
// 5:7 in a 50 × 70 unit box. Needs neon-core.js first.
//
// Faces are dark (P.face) with a thin rim. Ranks are Russo One in the suit colour;
// the centre suit glows. Every number and suit reaches 4.5:1 on the face (neon.test.js).
// Face cards stay letters until the face-art phase.

(function () {
  const window = typeof globalThis.window !== "undefined" ? globalThis.window : globalThis;
  const N = window.WarpedNeon || (typeof require !== "undefined" ? require("./neon-core.js") : null);
  const { P, n, glowId, glowDef, shape, text, SUIT_NAME } = N;

  // Card metrics, in the 50 × 70 box. export.js writes these to palette.json for the app.
  const M = {
    W: 50, H: 70, radius: 4.5, rimWidth: 1, inset: 3.4, insetWidth: 0.7, insetOpacity: 0.55,
    glowBlur: 0.9, glowBlurBig: 1.4,
    rank: { x: 9.5, y: 11, size: 13, size10: 11.5, tracking10: -0.8 },
    cornerSuit: { x: 9.5, y: 21, size: 7 },
    pip: { y: 37, size: 22 },
    abbrev: { rankX: 12.5, rankY: 17, rankSize: 17, suitY: 33, suitSize: 13, inlineSize: 19 },
    word: { size: 6, tracking: 1.2, y: 9.5 },
  };
  const { W, H } = M;
  const SUITS = Object.fromEntries(["S", "H", "D", "C"].map(s => [s, { name: SUIT_NAME[s], colour: P.suit[s] }]));
  const RANKS = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"];

  // The card's frame. rim is the edge colour; inner is drawn on top. glow, when set,
  // is the filter id defined in defs.
  function frame(inner, o = {}) {
    const g = glowId(), gb = glowId();
    const rim = o.rim || P.rim, face = o.face || P.face;
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" class="card-svg"><defs>${glowDef(g, M.glowBlur)}${glowDef(gb, M.glowBlurBig)}</defs>` +
      `<rect x="0.5" y="0.5" width="${W - 1}" height="${H - 1}" rx="${M.radius}" fill="${face}" stroke="${rim}" stroke-width="${M.rimWidth}"/>` +
      (typeof inner === "function" ? inner(g, gb) : inner) + `</svg>`;
  }
  const inset = (colour, opacity = M.insetOpacity, dash = "") =>
    `<rect x="${M.inset}" y="${M.inset}" width="${W - 2 * M.inset}" height="${H - 2 * M.inset}" rx="${M.radius - 1.6}" fill="none" stroke="${colour}" stroke-width="${M.insetWidth}" opacity="${opacity}" ${dash ? `stroke-dasharray="${dash}"` : ""}/>`;
  const turned = (s) => `<g transform="rotate(180 ${W / 2} ${H / 2})">${s}</g>`;
  const word = (t, colour, g) => text(W / 2, M.word.y, t, M.word.size, colour, `letter-spacing="${M.word.tracking}" filter="url(#${g})"`);

  // opts: { rank, suit, form: "standard" | "abbrev", layout: "corner" | "inline" (abbrev only) }
  function front(opts) {
    const c = P.suit[opts.suit], ten = opts.rank === "10";
    const rank = (x, y, size) => text(x, y, opts.rank, size, c, ten ? `letter-spacing="${M.rank.tracking10}"` : "");
    if (opts.form === "abbrev") {
      const a = M.abbrev;
      if (opts.layout === "inline") {
        return frame((g) => text(W / 2 - 6, H / 2, opts.rank, ten ? a.inlineSize - 3 : a.inlineSize, c, ten ? `letter-spacing="${M.rank.tracking10}"` : "") +
          shape(opts.suit, W / 2 + (ten ? 12 : 9), H / 2, a.inlineSize * .9, c, `filter="url(#${g})"`));
      }
      return frame((g) => rank(a.rankX, a.rankY, ten ? a.rankSize - 3 : a.rankSize) + shape(opts.suit, a.rankX, a.suitY, a.suitSize, c, `filter="url(#${g})"`));
    }
    const r = M.rank, cs = M.cornerSuit;
    const corner = rank(r.x, r.y, ten ? r.size10 : r.size) + shape(opts.suit, cs.x, cs.y, cs.size, c);
    return frame((g, gb) => corner + turned(corner) + shape(opts.suit, W / 2, M.pip.y - 2, M.pip.size, c, `filter="url(#${gb})"`));
  }

  // ---- Backs ---------------------------------------------------------------
  // Grid horizon: a sun over a perspective grid, cyan on the back colour, magenta rim.
  const BACKS = { horizon: { name: "Horizon", note: "Neon v1: a striped sun over a perspective grid" } };
  function back() {
    const clip = glowId(), sun = glowId();
    return frame((g) => {
      const x0 = 5, y0 = 5, w = W - 10, h = H - 10, hz = 38, vx = W / 2;
      let grid = "";
      for (let i = 0; i < 6; i++) { const y = hz + 1.2 * Math.pow(1.62, i); if (y < y0 + h) grid += `M${x0} ${n(y)}H${x0 + w}`; }
      for (let k = -6; k <= 6; k++) grid += `M${n(vx + k * 1.6)} ${hz}L${n(vx + k * 9)} ${y0 + h}`;
      const stripes = [31, 34, 36.5].map((y, i) => `<rect x="${vx - 13}" y="${y}" width="26" height="${0.9 + i * .35}" fill="${P.back}"/>`).join("");
      return `<defs><clipPath id="${clip}"><rect x="${x0}" y="${y0}" width="${w}" height="${h}" rx="2.4"/></clipPath>` +
        `<linearGradient id="${sun}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${P.gold}"/><stop offset="1" stop-color="${P.magenta}"/></linearGradient></defs>` +
        `<g clip-path="url(#${clip})"><rect x="${x0}" y="${y0}" width="${w}" height="${h}" fill="${P.back}"/>` +
        `<circle cx="${vx}" cy="${hz - 1}" r="12" fill="url(#${sun})" filter="url(#${g})"/>${stripes}<rect x="${x0}" y="${hz}" width="${w}" height="${h}" fill="${P.back}"/>` +
        `<path d="${grid}" stroke="${P.cyan}" stroke-width=".6" fill="none" opacity=".85"/>` +
        `<path d="M${x0} ${hz}H${x0 + w}" stroke="${P.magenta}" stroke-width=".9" filter="url(#${g})"/></g>` +
        `<rect x="5" y="5" width="${w}" height="${h}" rx="2.4" fill="none" stroke="${P.magenta}" stroke-width=".9" filter="url(#${g})"/>`;
    }, { face: P.back });
  }

  // ---- Jokers: amber and teal ------------------------------------------------
  const JOKERS = {
    amber: { name: "Amber joker", colour: P.joker.amber, symbol: "star" },
    teal: { name: "Teal joker", colour: P.joker.teal, symbol: "moon" },
  };
  function joker(kind) {
    const j = JOKERS[kind], c = j.colour;
    return frame((g, gb) => inset(c, 1) + word("JOKER", c, g) + turned(word("JOKER", c, g)) +
      shape(j.symbol, W / 2, H / 2, 26, c, `filter="url(#${gb})"`), { rim: c });
  }

  // ---- Special jokers (jokers that carry an action) ----------------------------
  const SPECIALS = {
    swap: { name: "Swapper", word: "SWAP", note: "Reverses a straight line of 2 to 4 grid cards" },
    bomb: { name: "Bomb", word: "BOMB", note: "Clears a card and its neighbours, without scoring" },
  };
  function special(type) {
    const s = SPECIALS[type], c = P.joker.special;
    return frame((g, gb) => inset(c, 1, "2.2 1.4") + word("JOKER", c, g) + turned(word(s.word, c, g)) +
      shape(type, W / 2, H / 2, 24, c, `filter="url(#${gb})"`), { rim: c });
  }

  // ---- Extra cards: the title card and a blank ---------------------------------
  const EXTRAS = {
    title: { name: "Title card", note: "Turns into a prize when drawn" },
    blank: { name: "Blank card", note: "Turns into a prize when drawn" },
  };
  function extra(type) {
    if (type === "title") {
      return frame((g) => inset(P.magenta, .8) +
        text(W / 2, 27, "WARPED", 7.6, P.cyan, `letter-spacing="1" filter="url(#${g})"`) + text(W / 2, 37, "CARDS", 7.6, P.magenta, `letter-spacing="1.6" filter="url(#${g})"`) +
        `<path d="M15 44.5h20" stroke="${P.muted}" stroke-width=".7"/>` + text(W / 2, 51, "52 + 2 JOKERS", 3.6, P.muted, `font-weight="600" letter-spacing=".4"`));
    }
    return frame(inset(P.muted, .9, "1.6 1.6"));
  }

  // ---- Prize faces: what a joker or extra card turns into, when it isn't a card -------
  const PRIZES = {
    steps: { name: "+5 steps", note: "Steps for this turn" },
    item: { name: "An item", note: "Goes to the tray. Items aren't designed yet" },
    none: { name: "Nothing", note: "The stock was empty" },
  };
  function prize(type, amount = 5) {
    if (type === "steps") return frame((g, gb) => inset(P.gold, 1) + text(W / 2, 31, "+" + amount, 17, P.gold, `filter="url(#${gb})"`) + text(W / 2, 46, "STEPS", 5.4, P.gold, `letter-spacing="1.2"`), { rim: P.gold });
    if (type === "item") return frame((g, gb) => inset(P.gold, 1, "2.2 1.4") + shape("item", W / 2, 31, 22, P.gold, `filter="url(#${gb})"`) + text(W / 2, 52, "ITEM", 5.4, P.gold, `letter-spacing="1.2"`), { rim: P.gold });
    return frame(inset(P.muted, .6, "1.6 1.6") + text(W / 2, H / 2, "NONE", 5.4, P.muted, `letter-spacing="1.2"`));
  }

  // ---- Item icons (maze items and tray) -------------------------------------------
  const ITEMS = {
    jump: { name: "Jump ahead", colour: P.cyan }, key: { name: "Skeleton key", colour: P.gold }, steps: { name: "Extra steps", colour: P.gold },
    item: { name: "Unknown item", colour: P.gold }, swap: { name: "Swapper", colour: P.joker.special }, bomb: { name: "Bomb", colour: P.joker.special },
  };
  // A round tray button, size px across, with the icon glowing in its colour.
  function itemIcon(type, size = 44, label = "") {
    const c = ITEMS[type].colour, g = glowId();
    return `<svg viewBox="0 0 44 44" width="${size}" height="${size}" class="icon-svg"><defs>${glowDef(g, 1.4)}</defs>` +
      `<rect x="1" y="1" width="42" height="42" rx="11" fill="${P.panel}" stroke="${c}" stroke-width="1.6" filter="url(#${g})"/>` +
      shape(type, 22, label ? 19 : 22, 22, c, `filter="url(#${g})"`) + (label ? text(22, 36.5, label, 7.5, c) : "") + `</svg>`;
  }

  // ---- Markers on cards ---------------------------------------------------------
  // Drawn over a card (the match turn places them with CSS; the app natively).
  const MARKERS = {
    power: { name: "Edge power", colour: P.cyan, note: "A pill in the top-right corner with the multiplier" },
    starter: { name: "Starter tag", colour: P.gold, note: "Under the starter, which is tilted" },
    kept: { name: "New card star", colour: P.gold, note: "A card a joker made, kept for the game" },
    edge: { name: "Edge card ring", colour: P.gold, note: "Hand, crib and starter cards around the grid" },
    lit: { name: "Lit combo", colour: P.cyan, note: "Cards in a combo while tracing" },
  };
  // A pill with text, for edge power (×1.5) and the starter tag. Height h px.
  function pill(t, colour, h = 18, filled = true) {
    const w = Math.max(h * 1.4, t.length * h * .5 + h * .8), g = glowId();
    return `<svg viewBox="0 0 ${n(w + 4)} ${h + 4}" width="${n(w + 4)}" height="${h + 4}" class="pill-svg"><defs>${glowDef(g, 1.2)}</defs>` +
      `<rect x="2" y="2" width="${n(w)}" height="${h}" rx="${h / 2}" fill="${filled ? colour : P.bg}" stroke="${colour}" stroke-width="1.4" filter="url(#${g})"/>` +
      text(2 + w / 2, 2 + h / 2 + .5, t, h * .55, filled ? P.bg : colour) + `</svg>`;
  }
  function keptStar(size = 16) {
    const g = glowId();
    return `<svg viewBox="0 0 20 20" width="${size}" height="${size}" class="pill-svg"><defs>${glowDef(g, 1)}</defs>${shape("star", 10, 10, 17, P.gold, `filter="url(#${g})" stroke="#2B2A26" stroke-width="1.6" stroke-linejoin="round" paint-order="stroke"`)}</svg>`;
  }

  // Contrast (WCAG 2), kept here so pages that used WarpedCards.contrast still work.
  const contrast = N.contrast;
  const FACE = { face: P.face, rule: P.rim, ink: P.text, soft: P.muted };

  const api = { M, W, H, FACE, SUITS, RANKS, BACKS, SPECIALS, EXTRAS, JOKERS, PRIZES, ITEMS, MARKERS,
    front, back, special, extra, joker, prize, itemIcon, pill, keptStar, contrast };
  if (typeof module !== "undefined") module.exports = api;
  window.WarpedNeonCards = api;
})();
