// The card art every build draws from (README.md): each SVG keeps to the subset the builds read,
// and every colour in it is in palette.json, so tinting from the palette and drawing the hex agree.
const test = require("node:test");
const assert = require("node:assert");
const fs = require("fs"), path = require("path");

const dir = __dirname;
const svgs = fs.readdirSync(dir).filter((f) => f.endsWith(".svg"));
const palette = JSON.parse(fs.readFileSync(path.join(dir, "../neon/palette.json"), "utf8"));

function hexes(node, out = new Set()) {
  if (typeof node === "string" && /^#[0-9A-Fa-f]{6}$/.test(node)) out.add(node.toUpperCase());
  else if (node && typeof node === "object") for (const v of Object.values(node)) hexes(v, out);
  return out;
}
const known = hexes(palette.colours);
known.add("#FFFFFF");   // the bomb's highlight, white at 35%

test("the card art is there", () => {
  for (const f of ["frame", "back", "face-sample", "joker-swap", "joker-bomb", "joker-reach", "joker-burn",
    "extra-amber", "extra-teal", "extra-title", "extra-blank"]) assert.ok(svgs.includes(`${f}.svg`), `${f}.svg is missing`);
});

test("card art uses only the SVG the builds read", () => {
  const elements = new Set(["svg", "g", "rect", "circle", "path", "text", "clipPath"]);
  for (const f of svgs) {
    const src = fs.readFileSync(path.join(dir, f), "utf8").replace(/<!--[\s\S]*?-->/g, "");
    for (const [, name] of src.matchAll(/<([A-Za-z]+)[\s>/]/g)) assert.ok(elements.has(name), `${f}: <${name}> isn't read by the builds`);
    for (const [, d] of src.matchAll(/ d="([^"]*)"/g)) assert.ok(/^[MLHVCZmlhvcz0-9.,\s-]*$/.test(d), `${f}: path data beyond M L H V C Z`);
    for (const [, t] of src.matchAll(/transform="([^"]*)"/g)) assert.ok(/^((translate|rotate|scale)\([^)]*\)\s*)+$/.test(t), `${f}: transform ${t}`);
  }
});

test("every colour in the card art is in palette.json", () => {
  for (const f of svgs) {
    const src = fs.readFileSync(path.join(dir, f), "utf8");
    for (const [hex] of src.matchAll(/#[0-9A-Fa-f]{6}\b/g)) assert.ok(known.has(hex.toUpperCase()), `${f}: ${hex} isn't in palette.json colours`);
  }
});
