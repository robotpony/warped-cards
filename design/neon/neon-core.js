// Warped Cards, neon look: shared palette, glow, suit shapes and helpers (v1, 2026-11-14).
//
// Look C, "vector arcade", chosen by Bruce on 2026-11-14: glowing lines on near-black.
// Values match palette.json (the copy the Swift app reads); neon.test.js checks they
// stay in step and that the contrast rules hold.
//
// Rules for every neon asset:
// - Every glow has a solid core, so a shape reads with the blur off (Reduce Motion,
//   low power, small sizes). Glow is decoration, never the only edge.
// - Colour is never the only cue: suits keep their shape, bots their silhouette,
//   jokers their symbol.
// - Suits are drawn as paths, not font glyphs, so they never turn into emoji and
//   port as-is to the app.
//
// Plain script (no modules) so the mocks open straight from disk.

(function () {
  const window = typeof globalThis.window !== "undefined" ? globalThis.window : globalThis;

  const P = {
    bg: "#0A0E1F", panel: "#121A33", text: "#DDE6FF", muted: "#8A97C2", core: "#E6FFFF",
    face: "#10162E", rim: "#2E3A66", back: "#0B1024",
    cyan: "#3CF2FF", magenta: "#FF4FD8", gold: "#FFD447", door: "#FF8A3D",
    suit: { S: "#E8ECFF", H: "#FF4D6D", D: "#4DA3FF", C: "#3DDC84" },
    joker: { amber: "#FFB020", teal: "#2EE6D6", special: "#C77DFF" },
    tokens: ["#FFD447", "#34E0A1", "#B48CFF"],
  };
  const FONT = `"Russo One", "Saira Semi Condensed", system-ui, sans-serif`;
  const n = (v) => Math.round(v * 100) / 100;

  // A unique id for each glow filter. Ids are per SVG, so a hidden SVG earlier in the
  // page can never take another's filter away.
  let uid = 0;
  const glowId = () => "ng" + (++uid);
  const glowDef = (id, blur) =>
    `<filter id="${id}" filterUnits="userSpaceOnUse" x="-200" y="-200" width="4000" height="4000"><feGaussianBlur stdDeviation="${n(blur)}" result="b"/>` +
    `<feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>`;

  // Shapes: suits and icons as SVG path data in a 20 × 20 box, so the app can draw the
  // same paths. Each shape is a list of parts: { d, mode: "fill" | "stroke", w (stroke
  // width in box units), tint: "main" (the asset's colour) or a palette key like "gold" }.
  // export.js writes them to shapes.json.
  const circ = (cx, cy, r) => `M${cx - r} ${cy}a${r} ${r} 0 1 0 ${2 * r} 0a${r} ${r} 0 1 0 ${-2 * r} 0Z`;
  const starD = (cx, cy, R, r) => "M" + Array.from({ length: 10 }, (_, i) => {
    const a = -Math.PI / 2 + i * Math.PI / 5, d = i % 2 ? r : R;
    return `${n(cx + d * Math.cos(a))} ${n(cy + d * Math.sin(a))}`;
  }).join("L") + "Z";
  const F = (d, tint = "main") => ({ d, mode: "fill", tint });
  const L = (d, w, tint = "main") => ({ d, mode: "stroke", w, tint });
  const SHAPES = {
    H: [F("M10 18.6C10 18.6 1 12.4 1 6.6C1 3.6 3.3 1.4 5.9 1.4C7.8 1.4 9.2 2.6 10 4.2C10.8 2.6 12.2 1.4 14.1 1.4C16.7 1.4 19 3.6 19 6.6C19 12.4 10 18.6 10 18.6Z")],
    D: [F("M10 0.8L17.6 10L10 19.2L2.4 10Z")],
    S: [F("M10 0.8C10 0.8 1.4 7.4 1.4 12C1.4 14.6 3.4 16.4 5.8 16.4C7.3 16.4 8.6 15.7 9.3 14.6C9.1 16.6 8.2 18.1 6.6 19.2H13.4C11.8 18.1 10.9 16.6 10.7 14.6C11.4 15.7 12.7 16.4 14.2 16.4C16.6 16.4 18.6 14.6 18.6 12C18.6 7.4 10 0.8 10 0.8Z")],
    C: [F(circ(10, 5.4, 4.3) + circ(5.2, 11.4, 4.3) + circ(14.8, 11.4, 4.3) + circ(10, 10.4, 2.6) + "M9.1 11.5C9 15.4 8 17.6 6.4 19.2H13.6C12 17.6 11 15.4 10.9 11.5Z")],
    star: [F(starD(10, 10.6, 9.6, 4))],
    moon: [F("M13.5 1.2A9.2 9.2 0 1 0 13.5 18.8A10.6 10.6 0 0 1 13.5 1.2Z")],
    swap: [L("M3 6.5H16.5L13 3M17 13.5H3.5L7 17", 2.2)],
    bomb: [F(circ(9, 12, 6.6)), F("M11.6 4.4L15.6 6.9L14.1 9.3L10.1 6.8Z"), L("M14.6 5.4C15.4 3.2 17 2.2 18.6 2.6", 1.2, "muted"), F(starD(18.4, 2.4, 2.2, .9), "gold")],
    key: [L(circ(5.6, 10, 3.4) + "M9 10H18.6M15.6 10V13.6M18.3 10V12.8", 2)],
    jump: [L("M4 10.5L10 4.5L16 10.5M4 16L10 10L16 16", 2.2)],
    steps: [L("M2.5 10H14.5M10.5 5.5L15 10L10.5 14.5M18 5V15", 2.2)],
    item: [L("M3 6.6L10 3L17 6.6V13.6L10 17.2L3 13.6ZM3 6.6L10 10.2L17 6.6M10 10.2V17.2", 1.6)],
    play: [F("M6 3.6L16.4 10L6 16.4Z")],
    goal: [L("M10 1L19 10L10 19L1 10Z", 1.4), F("M10 5.6L14.4 10L10 14.4L5.6 10Z")],
  };
  const SUIT_NAME = { S: "Spades", H: "Hearts", D: "Diamonds", C: "Clubs" };
  // A shape centred on (cx, cy), size across. colour fills the "main" parts; other
  // tints come from the palette. extra goes on the group (a filter, an opacity).
  function shape(name, cx, cy, size, colour, extra = "") {
    const k = size / 20;
    const parts = SHAPES[name].map(p => {
      const c = p.tint === "main" ? colour : P[p.tint];
      return p.mode === "fill" ? `<path d="${p.d}" fill="${c}"/>` : `<path d="${p.d}" fill="none" stroke="${c}" stroke-width="${p.w}" stroke-linecap="round" stroke-linejoin="round"/>`;
    }).join("");
    return `<g transform="translate(${n(cx - size / 2)} ${n(cy - size / 2)}) scale(${n(k)})" ${extra}>${parts}</g>`;
  }
  const suit = (s, cx, cy, size, fill, extra = "") => shape(s, cx, cy, size, fill, extra);

  const text = (x, y, t, size, fill, extra = "") =>
    `<text x="${n(x)}" y="${n(y)}" text-anchor="middle" dominant-baseline="central" font-family='${FONT}' font-weight="400" font-size="${n(size)}" fill="${fill}" ${extra}>${t}</text>`;
  const star = (cx, cy, R, r) => Array.from({ length: 10 }, (_, i) => {
    const a = -Math.PI / 2 + i * Math.PI / 5, d = i % 2 ? r : R;
    return `${n(cx + d * Math.cos(a))},${n(cy + d * Math.sin(a))}`;
  }).join(" ");
  const poly = (cx, cy, r, k, rot = -Math.PI / 2) => Array.from({ length: k }, (_, i) => {
    const a = rot + i * 2 * Math.PI / k; return `${n(cx + r * Math.cos(a))},${n(cy + r * Math.sin(a))}`;
  }).join(" ");

  // WCAG 2 contrast.
  function luminance(hex) {
    const c = [1, 3, 5].map(i => parseInt(hex.slice(i, i + 2), 16) / 255)
      .map(v => (v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4));
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
  }
  function contrast(a, b) {
    const [hi, lo] = [luminance(a), luminance(b)].sort((x, y) => y - x);
    return (hi + 0.05) / (lo + 0.05);
  }

  const api = { P, FONT, n, glowId, glowDef, SHAPES, SUIT_NAME, shape, suit, text, star, poly, luminance, contrast };
  if (typeof module !== "undefined") module.exports = api;
  window.WarpedNeon = api;
})();
