// Builds every platform's app icon from the layer SVGs in layers/.
// Run from the repo root on a Mac: node design/icon/export.js
// Needs Google Chrome (to draw the SVGs) and sips (to resize), see LIBRARIES.md.
// Writes export/apple, export/linux and export/web. Don't edit those by hand.

const fs = require("fs"), path = require("path"), os = require("os");
const { execFileSync } = require("child_process");

const HERE = __dirname, LAYERS = path.join(HERE, "layers"), OUT = path.join(HERE, "export");
const CHROME = process.env.CHROME || "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

// A layer's drawing, without its outer <svg> element.
const layer = name => fs.readFileSync(path.join(LAYERS, name + ".svg"), "utf8")
  .replace(/^[\s\S]*?<svg[^>]*>/, "").replace(/<\/svg>\s*$/, "");
const svg = (body, defs = "") =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">${defs}${body}</svg>\n`;

// Full bleed, square corners: the platform rounds them (iOS, web home screens).
const art = (bg = "background") => layer(bg) + layer("cards") + layer("star");

const ICONS = {
  // iOS: light, dark and tinted. Tinted is grey on black; the system adds the tint.
  "ios-light": svg(art()),
  "ios-dark": svg(art("background-dark")),
  "ios-tinted": svg(`<rect width="1024" height="1024" fill="#000000"/><g filter="url(#grey)">${layer("cards")}${layer("star")}</g>`,
    `<defs><filter id="grey"><feColorMatrix type="saturate" values="0"/></filter></defs>`),
  // macOS: an 824 plate on the 1024 canvas, 185 corners, a soft drop shadow.
  mac: svg(`<rect x="100" y="112" width="824" height="824" rx="185" fill="#000000" fill-opacity="0.35" filter="url(#shadow)"/>` +
    `<g clip-path="url(#plate)"><g transform="translate(100 100) scale(0.8046875)">${art()}</g></g>`,
    `<defs><filter id="shadow" x="-10%" y="-10%" width="120%" height="130%"><feGaussianBlur stdDeviation="14"/></filter>` +
    `<clipPath id="plate"><rect x="100" y="100" width="824" height="824" rx="185"/></clipPath></defs>`),
  // Linux: a rounded plate with a small margin, as a scalable SVG.
  linux: svg(`<g clip-path="url(#plate)"><g transform="translate(64 64) scale(0.875)">${art()}</g></g>`,
    `<defs><clipPath id="plate"><rect x="64" y="64" width="896" height="896" rx="200"/></clipPath></defs>`),
  // Web maskable: the art at 80% so it survives any mask shape.
  maskable: svg(layer("background") + `<g transform="translate(102.4 102.4) scale(0.8)">${layer("cards")}${layer("star")}</g>`),
  favicon: svg(layer("favicon")),
};

const TMP = fs.mkdtempSync(path.join(os.tmpdir(), "cribmaze-icon-"));

// Draws an icon at 1024 with a transparent background.
function draw(name) {
  const src = path.join(TMP, name + ".svg"), png = path.join(TMP, name + ".png");
  fs.writeFileSync(src, ICONS[name]);
  execFileSync(CHROME, ["--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
    "--default-background-color=00000000", "--window-size=1024,1024", "--screenshot=" + png, "file://" + src], { stdio: "ignore" });
  return png;
}

function sized(png, px, dest) {
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  if (px === 1024) fs.copyFileSync(png, dest);
  else execFileSync("sips", ["-z", String(px), String(px), png, "--out", dest], { stdio: "ignore" });
  return dest;
}

// An .ico holding PNGs, one per size.
function ico(pngs, dest) {
  const head = Buffer.alloc(6 + 16 * pngs.length);
  head.writeUInt16LE(0, 0); head.writeUInt16LE(1, 2); head.writeUInt16LE(pngs.length, 4);
  let offset = head.length;
  const data = pngs.map(([px, file], i) => {
    const b = fs.readFileSync(file), e = 6 + 16 * i;
    head.writeUInt8(px >= 256 ? 0 : px, e); head.writeUInt8(px >= 256 ? 0 : px, e + 1);
    head.writeUInt16LE(1, e + 4); head.writeUInt16LE(32, e + 6);
    head.writeUInt32LE(b.length, e + 8); head.writeUInt32LE(offset, e + 12);
    offset += b.length;
    return b;
  });
  fs.writeFileSync(dest, Buffer.concat([head, ...data]));
}

function main() {
  fs.rmSync(OUT, { recursive: true, force: true });
  const p = Object.fromEntries(Object.keys(ICONS).map(n => [n, draw(n)]));
  const A = path.join(OUT, "apple"), L = path.join(OUT, "linux"), W = path.join(OUT, "web");

  sized(p["ios-light"], 1024, path.join(A, "ios-1024.png"));
  sized(p["ios-dark"], 1024, path.join(A, "ios-1024-dark.png"));
  sized(p["ios-tinted"], 1024, path.join(A, "ios-1024-tinted.png"));
  for (const px of [16, 32, 64, 128, 256, 512, 1024]) sized(p.mac, px, path.join(A, `mac-${px}.png`));

  fs.mkdirSync(L, { recursive: true });
  fs.writeFileSync(path.join(L, "crib-maze.svg"), ICONS.linux);
  for (const px of [16, 32, 48, 64, 128, 256, 512]) sized(p.linux, px, path.join(L, `crib-maze-${px}.png`));

  fs.mkdirSync(W, { recursive: true });
  fs.writeFileSync(path.join(W, "favicon.svg"), ICONS.favicon);
  ico([16, 32, 48].map(px => [px, sized(p.favicon, px, path.join(TMP, `fav-${px}.png`))]), path.join(W, "favicon.ico"));
  sized(p.favicon, 32, path.join(W, "favicon-32.png"));
  sized(p["ios-light"], 180, path.join(W, "apple-touch-icon.png"));
  sized(p["ios-light"], 192, path.join(W, "icon-192.png"));
  sized(p["ios-light"], 512, path.join(W, "icon-512.png"));
  sized(p.maskable, 512, path.join(W, "icon-maskable-512.png"));

  fs.rmSync(TMP, { recursive: true, force: true });
  console.log("Wrote", path.relative(process.cwd(), OUT));
}

if (require.main === module) main();
module.exports = { ICONS };
