// Warped Cards: card renderer (mock v2, 2026-11-14).
//
// Based on Scorekeep's card kit (~/projects/utilities/scorekeep/assets/cards,
// Scorekeep/Design/PlayfieldTokens.swift): width-driven 5:7 cards.
//
// Two forms:
// - standard: the game's cards. Rank in the top-left and bottom-right corners,
//   one large suit in the centre. Rank and suit share the suit colour.
// - abbrev: documentation and diagrams, as in Scorekeep. One rank and one
//   suit, in the corner (fans) or inline and centred (grids).
//
// Faces are light only, near white. Four-colour suits, each 4.5:1 or better
// on the face. Face cards are letters until the face-art phase. One back
// (Scorekeep's crosshatch) until the card-back design phase.
//
// Plain script (no modules) so the mocks open straight from disk.

(function () {
  const W = 50, H = 70, R = 4.5; // viewBox units; height = width * 1.4

  const FACE = { face: "#FDFCF8", rule: "#D6D0C4", ink: "#2B2A26", soft: "#7C6C48" };

  // Closest shade to each requested hue that reaches 4.5:1 on the face.
  const SUITS = {
    S: { glyph: "♠", name: "Spades",   colour: "#000000", asked: "#000000" },
    H: { glyph: "♥", name: "Hearts",   colour: "#E00000", asked: "#FF0000" },
    D: { glyph: "♦", name: "Diamonds", colour: "#0070E0", asked: "#00A3FF" },
    C: { glyph: "♣", name: "Clubs",    colour: "#00843D", asked: "#00A651" },
  };

  const RANKS = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"];
  const FONT = `"Saira Semi Condensed", "Arial Narrow", system-ui, sans-serif`;

  function frame(inner) {
    return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" class="card-svg">` +
      `<rect x="0.6" y="0.6" width="${W - 1.2}" height="${H - 1.2}" rx="${R}" fill="${FACE.face}" stroke="${FACE.rule}" stroke-width="1.2"/>` +
      inner + `</svg>`;
  }

  // opts: { rank, suit, form: "standard" | "abbrev", layout: "corner" | "inline" (abbrev only) }
  function front(opts) {
    const s = SUITS[opts.suit];
    const fill = s.colour;
    const ten = opts.rank === "10";
    const rankText = (x, y, size, extra) =>
      `<text x="${x}" y="${y}" text-anchor="middle" font-family='${FONT}' font-weight="700" font-size="${size}" ` +
      `fill="${fill}" letter-spacing="${ten ? -1.2 : 0}" ${extra || ""}>${opts.rank}</text>`;

    if (opts.form === "abbrev") {
      if (opts.layout === "inline") {
        return frame(
          `<text x="${W / 2}" y="${H / 2 + 8}" text-anchor="middle" font-family='${FONT}' font-weight="700">` +
          `<tspan font-size="${ten ? 21 : 24}" fill="${fill}" letter-spacing="${ten ? -1.2 : 0}">${opts.rank}</tspan>` +
          `<tspan font-size="21" fill="${fill}" dx="1">${s.glyph}</tspan></text>`);
      }
      return frame(rankText(12, 22, ten ? 18 : 21) +
        `<text x="12" y="38" text-anchor="middle" font-size="15" fill="${fill}">${s.glyph}</text>`);
    }

    // Standard: corner ranks, large centred suit.
    const rs = ten ? 14 : 16;
    return frame(
      rankText(9, 16, rs) +
      rankText(9, 16, rs, `transform="rotate(180 ${W / 2} ${H / 2})"`) +
      `<text x="${W / 2}" y="${H / 2 + 12}" text-anchor="middle" font-size="34" fill="${fill}">${s.glyph}</text>`);
  }

  // ---- Backs (one for now; more come in the card-back design phase) ------

  const BACKS = {
    crosshatch: { name: "Crosshatch", note: "Scorekeep's default back" },
  };

  function back() {
    const id = "hatch";
    return frame(
      `<defs><pattern id="${id}" width="3.4" height="3.4" patternUnits="userSpaceOnUse" patternTransform="rotate(45)">` +
      `<line x1="0" y1="0" x2="0" y2="3.4" stroke="${FACE.soft}" stroke-width="0.7" opacity="0.7"/>` +
      `<line x1="0" y1="0" x2="3.4" y2="0" stroke="${FACE.soft}" stroke-width="0.7" opacity="0.7"/></pattern></defs>` +
      `<rect x="4.5" y="4.5" width="41" height="61" rx="2.7" fill="none" stroke="${FACE.rule}" stroke-width="1"/>` +
      `<rect x="9" y="9" width="32" height="52" rx="1.8" fill="url(#${id})"/>`);
  }

  // ---- Special jokers (jokers that carry an action) -----------------------
  // Placeholder art until the face-art phase. Purple marks a joker.

  const JOKER = "#6A1B9A";
  const SPECIALS = {
    swap: { name: "Swapper", word: "SWAP", note: "Reverses a straight line of 2 to 4 grid cards" },
    bomb: { name: "Bomb",    word: "BOMB", note: "Clears a card and its neighbours, without scoring" },
  };

  function special(type) {
    const s = SPECIALS[type];
    const head = `<text x="${W / 2}" y="12" text-anchor="middle" font-family='${FONT}' font-weight="700" font-size="8" fill="${JOKER}" letter-spacing="1">JOKER</text>` +
      `<text x="${W / 2}" y="64" text-anchor="middle" font-family='${FONT}' font-weight="700" font-size="8" fill="${JOKER}" letter-spacing="1">${s.word}</text>`;
    let icon = "";
    if (type === "swap") {
      icon = `<path d="M13 30h22l-5-5M37 42H15l5 5" stroke="${JOKER}" stroke-width="3.2" fill="none" stroke-linecap="round" stroke-linejoin="round"/>`;
    } else if (type === "bomb") {
      icon = `<circle cx="23" cy="40" r="11" fill="${FACE.ink}"/>` +
        `<rect x="27" y="25" width="6" height="5" rx="1" fill="${FACE.ink}" transform="rotate(35 30 27.5)"/>` +
        `<path d="M32 25c2-4 5-5 8-4" stroke="${FACE.soft}" stroke-width="1.4" fill="none"/>` +
        `<path d="M41 17l1.2 2.6 2.8.4-2 2 .5 2.8-2.5-1.3-2.5 1.3.5-2.8-2-2 2.8-.4z" fill="#E00000"/>` +
        `<circle cx="19" cy="36" r="2.4" fill="#ffffff" opacity=".35"/>`;
    }
    return frame(`<rect x="3.5" y="3.5" width="43" height="63" rx="3" fill="none" stroke="${JOKER}" stroke-width="1" opacity=".5"/>` + head + icon);
  }

  // ---- Extra cards in the deck: the title card and a blank ---------------
  // Placeholder art. With the amber and teal jokers (below), these are the deck's 4
  // extra cards. Drawing one plays a reveal (Crib RPG rules › Jokers and extra cards).

  const EXTRAS = {
    title: { name: "Title card", note: "Turns into a prize when drawn" },
    blank: { name: "Blank card", note: "Turns into a prize when drawn" },
  };

  function extra(type) {
    const t = (x, y, size, text, fill, extraAttr) => `<text x="${x}" y="${y}" text-anchor="middle" font-family='${FONT}' font-weight="700" ` +
      `font-size="${size}" fill="${fill}" ${extraAttr || ""}>${text}</text>`;
    if (type === "title") {
      return frame(`<rect x="5" y="5" width="40" height="60" rx="2.5" fill="none" stroke="${FACE.soft}" stroke-width="1"/>` +
        t(W / 2, 30, 9, "WARPED", FACE.ink, `letter-spacing="1"`) + t(W / 2, 41, 9, "CARDS", FACE.ink, `letter-spacing="1"`) +
        `<path d="M15 47h20" stroke="${FACE.soft}" stroke-width="1"/>` + t(W / 2, 56, 5, "52 + 2 JOKERS", FACE.soft));
    }
    return frame(`<rect x="5" y="5" width="40" height="60" rx="2.5" fill="none" stroke="${FACE.rule}" stroke-width="1" stroke-dasharray="2 2"/>`);
  }

  // ---- Jokers: amber and teal -------------------------------------------
  // Two joker types, told apart by colour and symbol. Each colour reaches 4.5:1 or
  // better on the face and differs from the four suit colours and the named-joker purple.

  const JOKERS = {
    amber: { name: "Amber joker", colour: "#A85A00", symbol: "star" },
    teal:  { name: "Teal joker",  colour: "#007C80", symbol: "moon" },
  };

  function joker(kind) {
    const j = JOKERS[kind], c = j.colour;
    const word = (rot) => `<text x="${W / 2}" y="13" text-anchor="middle" font-family='${FONT}' font-weight="700" font-size="8" fill="${c}" letter-spacing="1" ${rot ? `transform="rotate(180 ${W / 2} ${H / 2})"` : ""}>JOKER</text>`;
    const icon = j.symbol === "star"
      ? `<path d="M25 24l3.5 7.2 7.9.9-5.8 5.4 1.5 7.8-7.1-3.9-7.1 3.9 1.5-7.8-5.8-5.4 7.9-.9z" fill="${c}"/>`
      : `<path d="M28 24A11 11 0 1 0 28 46A13 13 0 0 1 28 24Z" fill="${c}"/>`;
    return frame(`<rect x="3.5" y="3.5" width="43" height="63" rx="3" fill="none" stroke="${c}" stroke-width="1.2"/>` + word(false) + icon + word(true));
  }

  // ---- Contrast (WCAG 2) -------------------------------------------------

  function luminance(hex) {
    const c = [1, 3, 5].map(i => parseInt(hex.slice(i, i + 2), 16) / 255)
      .map(v => (v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4));
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
  }
  function contrast(a, b) {
    const [hi, lo] = [luminance(a), luminance(b)].sort((x, y) => y - x);
    return (hi + 0.05) / (lo + 0.05);
  }

  window.WarpedCards = { W, H, FACE, SUITS, RANKS, BACKS, SPECIALS, EXTRAS, JOKERS, front, back, special, extra, joker, contrast };
})();
