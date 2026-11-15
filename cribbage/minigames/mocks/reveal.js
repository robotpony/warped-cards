// Crib Maze: the reveal, shared by the joker mock and the match turn (2026-11-14).
//
// When a joker or extra card is drawn, play pauses and this plays on a stage over the
// phone screen:
//
//   1. First meeting only: the card's name and a one-line hint (no odds).
//   2. Randomness: a shuffle, a wheel or a die of the drawn card's face.
//   3. The prize, revealed. The size follows its tier: quiet, glint or burst.
//   4. The prize's name, then it flies to its target (a board cell, the deck, the tray).
//
// Players never see the outcome list or the chances (concept.md › Decisions).
// A tap anywhere calls skip(), and the rest plays almost at once.
// Needs reveal.css, and a .stage element with .rays and .caption children.

(function () {
  let SKIP = false, SPEED = 1;
  const k = () => SKIP ? 0.02 : SPEED;
  const wait = (ms) => new Promise(r => setTimeout(r, ms * k()));
  const setT = (el, ms, ease) => el.style.transition = `transform ${ms * k()}ms ${ease || "cubic-bezier(.3,.7,.3,1)"}, opacity ${ms * k()}ms`;

  function card(stage, art, x, y) {
    const el = document.createElement("div");
    el.className = "sc";
    el.innerHTML = `<div class="f">${art}</div><div class="b"></div>`;
    el.style.transform = `translate(${x || 0}px, ${y || 0}px)`;
    stage.appendChild(el);
    return el;
  }

  // Each animation ends with one card at the centre, ready to flip, and returns it.
  const ANIMS = {
    // A row of five swaps places, then one steps forward.
    async shuffle(stage, art) {
      const xs = [-130, -65, 0, 65, 130], cards = xs.map(x => card(stage, art, x, 0)), pos = [...xs];
      await wait(250);
      for (let round = 0; round < 9; round++) {
        const a = Math.floor(Math.random() * 5); let b = Math.floor(Math.random() * 4); if (b >= a) b++;
        [pos[a], pos[b]] = [pos[b], pos[a]];
        const lift = round % 2 ? -26 : 26;
        cards.forEach((c, j) => { setT(c, 170 + round * 12); c.style.transform = `translate(${pos[j]}px, ${j === a || j === b ? lift : 0}px)`; });
        await wait(170 + round * 12);
        cards.forEach((c, j) => { c.style.transform = `translate(${pos[j]}px, 0)`; });
      }
      await wait(150);
      const pick = pos.indexOf(0), chosen = cards[pick];
      cards.forEach((c, j) => { if (j !== pick) { setT(c, 300); c.style.opacity = 0; c.style.transform += " scale(.7)"; } });
      setT(chosen, 300); chosen.style.transform = "translate(0, 0) scale(1.4)";
      await wait(320);
      cards.forEach((c, j) => { if (j !== pick) c.remove(); });
      return chosen;
    },
    // A wheel of eight spins and slows; the one at the top comes forward.
    async wheel(stage, art) {
      const wheel = document.createElement("div");
      wheel.style.cssText = "position:absolute;left:50%;top:50%;width:0;height:0;";
      stage.appendChild(wheel);
      const n = 8;
      for (let j = 0; j < n; j++) {
        const c = card(wheel, art);
        c.style.left = "0"; c.style.top = "0";
        c.style.transform = `rotate(${j * 360 / n}deg) translateY(-118px) scale(.7)`;
      }
      await wait(200);
      const end = Math.round((3 + Math.random() * 0.5) * n) * (360 / n);
      wheel.style.transition = `transform ${2400 * k()}ms cubic-bezier(.12,.6,.15,1)`;
      wheel.style.transform = `rotate(${end}deg)`;
      await wait(2450);
      wheel.remove();
      const chosen = card(stage, art, 0, -118);
      chosen.style.transform = "translate(0, -118px) scale(.7)";
      await wait(30);
      setT(chosen, 380); chosen.style.transform = "translate(0, 0) scale(1.4)";
      await wait(400);
      return chosen;
    },
    // A die with the face on every side tumbles and lands.
    async die(stage, art, colour) {
      const cube = document.createElement("div"); cube.className = "cube";
      const faces = ["rotateY(0deg)", "rotateY(90deg)", "rotateY(180deg)", "rotateY(-90deg)", "rotateX(90deg)", "rotateX(-90deg)"];
      cube.innerHTML = faces.map(f => `<div class="face" style="transform:${f} translateZ(48px);border-color:${colour || "#ccc"}">${art}</div>`).join("");
      cube.style.transform = "translateY(-240px) rotateX(-30deg) rotateY(20deg)";
      stage.appendChild(cube);
      await wait(60);
      cube.style.transition = `transform ${1900 * k()}ms cubic-bezier(.2,.8,.25,1)`;
      cube.style.transform = "translateY(0) rotateX(1080deg) rotateY(1080deg)";
      await wait(1950);
      const chosen = card(stage, art); chosen.style.transform = "scale(1.1)"; chosen.style.opacity = 0;
      await wait(20);
      setT(chosen, 260); chosen.style.opacity = 1; chosen.style.transform = "scale(1.4)";
      cube.style.transition = `opacity ${260 * k()}ms`; cube.style.opacity = 0;
      await wait(280); cube.remove();
      return chosen;
    },
  };

  // Flip to the prize. Bigger for rarer prizes.
  async function reveal(stage, el, prizeHtml, tier) {
    el.querySelector(".b").innerHTML = prizeHtml;
    if (tier === "burst") { await wait(300); el.style.transition = `transform ${350 * k()}ms ease-in`; el.style.transform = "scale(1.55) rotate(-4deg)"; await wait(380); }
    setT(el, tier === "quiet" ? 320 : 480);
    el.style.transform = `scale(${tier === "burst" ? 1.7 : 1.45}) rotateY(180deg)`;
    await wait(tier === "quiet" ? 330 : 500);
    if (tier === "glint") el.classList.add("glint");
    if (tier === "burst") { el.classList.add("burst"); const r = stage.querySelector(".rays"); r.classList.remove("on"); void r.offsetWidth; r.classList.add("on"); }
    await wait({ quiet: 450, glint: 900, burst: 1500 }[tier]);
  }

  async function flyTo(el, target) {
    const a = el.getBoundingClientRect(), t = target.getBoundingClientRect();
    const dx = (t.left + t.width / 2) - (a.left + a.width / 2), dy = (t.top + t.height / 2) - (a.top + a.height / 2);
    const s = Math.max(0.4, Math.min(t.width, 64) / el.offsetWidth); // offsetWidth ignores the current scale
    setT(el, 520, "cubic-bezier(.5,0,.3,1)");
    el.style.transform = `translate(${dx}px, ${dy}px) scale(${s}) rotateY(180deg)`;
    await wait(540);
    el.remove();
  }

  // o: { stage, art (SVG of the drawn card), colour, intro: { name, hint, colour } or null,
  //      prizeHtml, prizeName, tier, target (element or a function returning one),
  //      anim: "shuffle" | "wheel" | "die" | "random", speed (1 normal, 0.6 quick, 1.4 slow) }
  async function play(o) {
    SKIP = false; SPEED = o.speed || 1;
    const stage = o.stage, cap = stage.querySelector(".caption");
    stage.classList.add("on");
    cap.innerHTML = o.intro ? `<b style="color:${o.intro.colour || "#F3ECDC"}">${o.intro.name}</b><span>${o.intro.hint}</span>` : "";
    cap.classList.toggle("on", !!o.intro);
    await wait(o.intro ? 1100 : 200);
    const anim = !o.anim || o.anim === "random" ? ["shuffle", "wheel", "die"][Math.floor(Math.random() * 3)] : o.anim;
    const el = await ANIMS[anim](stage, o.art, o.colour);
    cap.classList.remove("on");
    await reveal(stage, el, o.prizeHtml, o.tier);
    cap.innerHTML = `<b>${o.prizeName}</b>`; cap.classList.add("on");
    await wait(o.tier === "quiet" ? 300 : 700);
    cap.classList.remove("on");
    await flyTo(el, typeof o.target === "function" ? o.target() : o.target);
    stage.querySelectorAll(".sc,.cube").forEach(e => e.remove());
    stage.classList.remove("on");
    SKIP = false;
    return anim;
  }

  window.WarpedReveal = { play, skip: () => { SKIP = true; }, ANIMS: Object.keys(ANIMS) };
})();
