class_name Breakdown extends Control
## The score breakdown (ui.md › Score breakdown): the set's cards fly up into a row over the board,
## a banner names the set, each part lights and adds a tally line, the total flies to the steps.
## The board shows the turn from before the score until it ends. A tap skips to the hold; a tap
## at the hold moves on. Sits over the board, in its coordinates.

signal stopped   ## snapshots: the breakdown reached the wait it was told to stop at (--stage)
signal held      ## the hold is showing

var session: Session
var board: Board
var header: Parts.Header

var active := false
var skipping := false
var holding := false
var stop_at := -1
var at_stop := false
var _waits := 0
var _resume := false

var fade := 0.0          ## the panel over the board
var row: Array[int] = [] ## the set's positions in count order, the starter last
var row_cards := {}      ## position → RowCard
var chips := {}          ## position → chip text on row cards
var lit: Array = []
var power: Array = []
var left: Array = []
var banner := {}         ## kind, head, suit
var banner_in := 0.0
var tally: Array = []    ## TallyLine
var tally_in := 0.0
var hold_in := 0.0
var floats: Array = []   ## Float
var fly := {}            ## text, from (phone), to (phone)
var fly_t := 0.0

const ROW_W := 50.0
const ROW_H := ROW_W * 1.4
const ROW_GAP := 6.0
const STARTER_GAP := 18.0
const BANNER_H := 50.0
const ROW_TOP := BANNER_H + 22.0
const TALLY_TOP := ROW_TOP + ROW_H + 14.0

class RowCard extends RefCounted:
	var p := 0
	var card := ""
	var index := 0
	var t := 0.0      ## 0 at its cell, 1 in the row
	var lift := 0.0
	var glow := 0.0

class TallyLine extends RefCounted:
	var name := ""
	var pts := ""
	var run := ""
	var style := "normal"   ## normal, power, penalty, total
	var cards: Array = []
	var shown := 0.0

class Float extends RefCounted:
	var at := Vector2.ZERO
	var text := ""
	var sub := ""
	var style := "normal"
	var age := 0.0

func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	size = Vector2(Look.BOARD_W, Look.BOARD_H)

func _ready() -> void:
	session.breakdown.connect(_play)

# MARK: Pace (ui.md › Score breakdown › Pace)

var _n := 0
func _step_ms() -> float:
	var t: Dictionary = session.timing
	var ms: float = max(float(t.breakdownMin), session.breakdown_base * pow(float(t.breakdownStep), _n))
	_n += 1
	return ms

func _scale() -> float:
	return session.breakdown_base / float(session.timing.breakdownBase)

## Waits out a cue; a skip ends every wait at once. Snapshots can stop at the Nth wait.
func _wait(ms: float) -> void:
	_waits += 1
	if _waits == stop_at:
		at_stop = true
		stopped.emit()
		while true:
			await get_tree().process_frame
	if skipping or ms <= 0:
		return
	var until := Time.get_ticks_msec() + Motion.secs(ms) * 1000.0
	while Time.get_ticks_msec() < until and not skipping:
		await get_tree().process_frame

## A tap anywhere on the phone while the breakdown shows.
func tap() -> void:
	if holding:
		_resume = true
	else:
		skipping = true

# MARK: The sequence (ui.md › Score breakdown › Cue sheet)

static func display_name(c: Dictionary) -> String:
	match c.kind:
		"fifteen": return "Fifteen"
		"pair": return {2: "Pair", 3: "Pair royal", 4: "Double pair royal"}.get(int(c.get("size", 2)), "%d of a kind" % int(c.get("size", 2)))
		"run":
			var m := int(c.get("multiplier", 1))
			return {1: "Run", 2: "Double run", 3: "Triple run", 4: "Double double run"}.get(m, "%d runs" % m) + " of %d" % int(c.get("size", 3))
		"flush": return "Flush of %d" % int(c.get("size", 4))
		"nobs": return "His nobs"
	return c.kind

## The set's headline: its biggest combo that isn't a fifteen (the first of the biggest), or its fifteens.
static func headline(combos: Array) -> String:
	var rest := combos.filter(func(c): return c.kind != "fifteen")
	var f := combos.size() - rest.size()
	if not rest.is_empty():
		var top := -1
		var best = null
		for c in rest:
			if int(c.points) > top:
				top = int(c.points)
				best = c
		return display_name(best)
	var words := ["", "", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight"]
	return "Fifteen" if f == 1 else (words[f] if f < words.size() else str(f)) + " fifteens"

static func signed(n: int) -> String:
	return "+%d" % n if n > 0 else ("−%d" % -n if n < 0 else "0")

static func _share(pct: int) -> String:
	return String.num(pct / 100.0, 2)

func _play(score: Dictionary, before: Dictionary) -> void:
	_reset()
	active = true
	_n = 0
	var sel: Array[int] = []
	for name in score.positions:
		sel.append(Board.parse_pos(name))
	var combos: Array = score.combos
	var suit_text: String = {"S": "♠", "H": "♥", "D": "♦", "C": "♣"}.get(score.get("suit", ""), "no suit")
	var head := headline(combos)
	var ep: Dictionary = session.rules.match.edgePower
	var card := func(p: int) -> String: return before.cells[p].card
	var level := func(p: int) -> int: return int(before.power[p]) if p >= 16 else 0
	var w: Dictionary = Motion.wait("breakdown")

	Motion.animate(self, "fade", 1.0, Motion.spec("breakdown.fade"), true, self)
	for i in sel.size():
		var rc := RowCard.new()
		rc.p = sel[i]
		rc.card = card.call(sel[i])
		rc.index = i
		row_cards[sel[i]] = rc
		if level.call(sel[i]) > 0:
			chips[sel[i]] = session.multiplier_text(level.call(sel[i]))
	_board()
	await _wait(w.beforeRow * _scale())
	# The cards leave the board (their cells empty, the rest dims) and fly up into the row.
	row = sel
	board.bd.set = sel
	board.bd.row = sel
	_board()
	await get_tree().create_timer(w.rowBeat / 1000.0).timeout
	var fly_spec := Motion.spec("breakdown.rowFly")
	for p in sel:
		var rc: RowCard = row_cards[p]
		var delay := Motion.secs(rc.index * float(w.rowStagger))
		get_tree().create_timer(delay).timeout.connect(func(): Motion.animate(rc, "t", 1.0, fly_spec, true, self))
	await _wait(w.beforeBanner * _scale())
	banner = {"kind": "MULTI ×%d" % combos.size() if combos.size() > 1 else "SINGLE", "head": head, "suit": suit_text}
	Motion.animate(self, "banner_in", 1.0, Motion.spec("breakdown.banner"), true, self)
	await _wait(w.beforeTally * _scale())
	Motion.animate(self, "tally_in", 1.0, Motion.spec("breakdown.tally"), true, self)
	# r16: the starter joined this set. It lights first, so it reads as part of every score.
	if sel.has(24) and session.turn.starterJoins:
		_light([24], "lit")
		_float([24], "Starter", "joins the set")
		_line("Starter joins", "", "", "normal", [card.call(24)])
		await _wait(_step_ms())
		_light([], "lit")
	var total := 0
	for c in combos:
		var ps: Array = c.cards.map(func(i): return sel[int(i)])
		total += int(c.points)
		_light(ps, "lit")
		_float(ps, "+%d" % int(c.points), display_name(c))
		_line(display_name(c), signed(int(c.points)), str(total), "normal", ps.map(card))
		var ms := _step_ms()
		await _wait(ms * float(w.comboLitPercent) / 100.0)
		_light([], "lit")
		await _wait(ms * (100.0 - float(w.comboLitPercent)) / 100.0)
	# Edge power multiplies the combos: each powered card lights with its share, then the set's applies.
	var powered := sel.filter(func(p): return p >= 16 and level.call(p) > 0)
	var adds: bool = ep.combine != "each"
	for p in powered:
		_light([p], "power")
		var m: String = "+" + _share(int(ep.percentPerLevel) * level.call(p)) if adds else session.multiplier_text(level.call(p))
		_float([p], m, "edge power", "power")
		_line("Starter power" if p == 24 else "Edge power", m, "", "power", [card.call(p)])
		await _wait(_step_ms())
		_light([], "power")
	if adds and int(ep.capPercent) > 0 and not powered.is_empty():
		var sum := 100
		for p in powered:
			sum += int(ep.percentPerLevel) * level.call(p)
		if sum > int(ep.capPercent):
			_line("Power cap: %s is held at" % Session.multiplier_percent(sum), Session.multiplier_percent(int(ep.capPercent)), "", "power")
			await _wait(_step_ms())
	# r20: each joker-made card in the set adds its own multiplier.
	var made_in := sel.filter(func(p): return before.cells[p].has("percent"))
	for p in made_in:
		_light([p], "power")
		var m := Session.multiplier_percent(int(before.cells[p].percent))
		_float([p], m, "joker card", "power")
		_line("Joker card", m, "", "power", [card.call(p)])
		await _wait(_step_ms())
		_light([], "power")
	if not powered.is_empty() or not made_in.is_empty():
		var gain := int(score.multipliedPoints) - total
		total = int(score.multipliedPoints)
		_float(sel, Session.multiplier_percent(int(score.multiplierPercent)), "+%d" % gain, "power")
		_line("Total multi", Session.multiplier_percent(int(score.multiplierPercent)), str(total), "power")
		await _wait(_step_ms())
	# Cards left over cost steps, one line each, not multiplied.
	var used := {}
	for c in combos:
		for i in c.cards:
			used[int(i)] = true
	var cost := int(session.rules.match.leftOverCost)
	for i in sel.size():
		if used.has(i):
			continue
		var p := sel[i]
		total -= cost
		left.append(p)
		_light_motion(p)
		_board()
		_float([p], "−%d" % cost, "left over", "penalty")
		_line("Left over", "−%d" % cost, str(total), "penalty", [card.call(p)])
		await _wait(_step_ms())
	# Power up: every edge card in the set gains a level for later scores.
	var edges := sel.filter(func(p): return p >= 16)
	if not edges.is_empty():
		_line("Power up", "▲", "", "power", edges.map(card))
		var step := int(ep.step)
		_light(edges, "power")
		for p in edges:
			chips[p] = session.multiplier_text(level.call(p) + step)
			board.bd.chips[p] = level.call(p) + step
		for p in edges:
			_float([p], "▲", session.multiplier_text(level.call(p) + step), "power")
		await _wait(_step_ms())
		_light([], "power")
	_line("%s · %s" % [head, suit_text], signed(int(score.points)), "", "total")
	await _wait(max(float(session.timing.breakdownMin), float(w.afterTotal) * _scale()))
	await _hold()
	# The total floats up to the steps number as the cards fly home.
	fly = {"text": signed(int(score.points)), "from": _total_point(), "to": get_global_transform().affine_inverse() * header.steps_point()}
	fly_t = 0.0
	Motion.animate(self, "fly_t", 1.0, Motion.spec("breakdown.totalFly"), true, self)
	Motion.animate(self, "tally_in", 0.0, Motion.spec("breakdown.tally"), true, self)
	Motion.animate(self, "banner_in", 0.0, Motion.spec("breakdown.tally"), true, self)
	for p in row:
		Motion.animate(row_cards[p], "t", 0.0, fly_spec, true, self)
	await get_tree().create_timer(Motion.secs(w.flyHome)).timeout
	# The breakdown clears; the board moves on (Session commits).
	fly = {}
	active = false
	Motion.animate(self, "fade", 0.0, Motion.spec("breakdown.fade"), true, self)
	_reset_board()
	session.breakdown_done.emit()

func _hold() -> void:
	holding = true
	_resume = false
	Motion.animate(self, "hold_in", 1.0, Motion.spec("breakdown.tally"), true, self)
	held.emit()
	while not _resume:
		await get_tree().process_frame
	holding = false
	hold_in = 0.0

func _reset() -> void:
	skipping = false
	holding = false
	_waits = 0
	row = []
	row_cards = {}
	chips = {}
	lit = []
	power = []
	left = []
	banner = {}
	banner_in = 0.0
	tally = []
	tally_in = 0.0
	hold_in = 0.0
	floats = []
	fly = {}

func _reset_board() -> void:
	board.bd = {"active": false, "set": [], "lit": [], "power": [], "left": [], "row": [], "chips": {}, "pulse": []}
	row = []
	row_cards = {}
	_board()

func _board() -> void:
	board.bd.active = active
	board.bd.lit = lit
	board.bd.power = power
	board.bd.left = left
	board.bd.pulse = power
	board._restyle()
	queue_redraw()

func _light(ps: Array, kind: String) -> void:
	if kind == "lit":
		lit = ps
	else:
		power = ps
	for p in row_cards:
		_light_motion(p)
	_board()

func _light_motion(p: int) -> void:
	var rc: RowCard = row_cards[p]
	var on := lit.has(p) or power.has(p) or left.has(p)
	var up := lit.has(p) or power.has(p)
	var s := Motion.spec("breakdown.light" if on else "breakdown.unlight")
	Motion.animate(rc, "lift", -10.0 if up else 0.0, s, true, self)
	Motion.animate(rc, "glow", 1.0 if on else 0.0, s, true, self)

func _line(name: String, pts: String, run: String, style: String, cards: Array = []) -> void:
	var l := TallyLine.new()
	l.name = name
	l.pts = pts
	l.run = run
	l.style = style
	l.cards = cards
	tally.append(l)
	Motion.animate(l, "shown", 1.0, Motion.spec("breakdown.tallyLine"), true, self)

func _float(ps: Array, text: String, sub: String, style := "normal") -> void:
	if skipping:
		return
	var sum := Vector2.ZERO
	for p in ps:
		sum += _place(p)
	var f := Float.new()
	f.at = sum / max(1, ps.size())
	f.text = text
	f.sub = sub
	f.style = style
	floats.append(f)

## Where a card is now: its slot in the row once it's up, or its cell.
func _place(p: int) -> Vector2:
	if row.has(p):
		return _row_centre(p)
	return Board.frame(p).get_center()

func _row_centre(p: int) -> Vector2:
	var i := row.find(p)
	var n := row.size()
	var apart: bool = n > 1 and row.back() == 24
	var total := n * ROW_W + (n - 1) * ROW_GAP + (STARTER_GAP - ROW_GAP if apart else 0.0)
	var x := (Look.BOARD_W - total) / 2 + i * (ROW_W + ROW_GAP) + ROW_W / 2
	if apart and i == n - 1:
		x += STARTER_GAP - ROW_GAP
	return Vector2(x, ROW_TOP + ROW_H / 2)

func _process(delta: float) -> void:
	if not active and fade <= 0.0 and fly.is_empty():
		return
	var life: float = Motion.secs(Motion.wait("float.life"))
	for f in floats:
		f.age += delta
	floats = floats.filter(func(f): return f.age < life)
	queue_redraw()

# MARK: Drawing

func _style_colour(style: String) -> Color:
	match style:
		"total": return Look.colour("text")
		"power": return Look.colour("cyan")
		"penalty": return Look.colour("leftOver.text")
	return Look.colour("gold")

func _draw() -> void:
	if fade > 0.0:
		var pad := Look.EDGE_PAD_OUTER + 8
		draw_style_box(Look.box(Look.colour("bg", 0.94 * fade), 16), Rect2(-pad, -pad, size.x + 2 * pad, size.y + 2 * pad))
	if banner_in > 0.0 and not banner.is_empty():
		_draw_banner()
	if tally_in > 0.0 and not tally.is_empty():
		_draw_tally()
	for p in row:
		_draw_row_card(row_cards[p])
	for f in floats:
		_draw_float(f)
	if not fly.is_empty():
		var k := fly_t
		var at: Vector2 = (fly.from as Vector2).lerp(fly.to, k)
		var s: float = lerp(34.0, 26.0, k)
		var gold := Look.colour("gold")
		for o in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2), Vector2(-3, -3), Vector2(3, 3), Vector2(3, -3), Vector2(-3, 3)]:
			Look.draw_text_centred(self, at + o, fly.text, s, Look.colour("gold", 0.12), "Bold")   # the gold glow
		Look.draw_text_centred(self, at, fly.text, s, gold, "Bold")

func _draw_banner() -> void:
	var kind: String = banner.kind
	var tag_w := Look.text_width(kind, 11, "Bold", 1.1) + 12
	var head_w := Look.text_width(banner.head, 22, "Bold")
	var suit_w := Look.text_width(banner.suit, 13, "SemiBold") + 12
	var w := 16 + tag_w + 8 + head_w + 8 + suit_w + 16
	var h := 22.0 + 6 + 6 + 8
	var k := 0.9 + 0.1 * banner_in
	var centre := Vector2(size.x / 2, BANNER_H / 2 - 8 * (1.0 - banner_in))
	draw_set_transform(centre, 0, Vector2(k, k))
	var a: float = clamp(banner_in, 0.0, 1.0)
	var r := Rect2(-w / 2, -h / 2, w, h)
	draw_style_box(Look.box(Look.colour("gold", a), 12, Color.TRANSPARENT, 0, Look.colour("gold", 0.5 * a), 10), r)
	var x := r.position.x + 16
	draw_style_box(Look.box(Look.colour("ink", a), 6), Rect2(x, -10, tag_w, 20))
	Look.draw_text_centred(self, Vector2(x + tag_w / 2, 0), kind, 11, Look.colour("gold", a), "Bold", 1.1)
	x += tag_w + 8
	Look.draw_text(self, Vector2(x, Look.baseline_for_centre(0, 22, "Bold")), banner.head, 22, Look.colour("ink", a), "Bold")
	x += head_w + 8
	draw_style_box(Look.box(Look.colour("paper", a), 6), Rect2(x, -10, suit_w, 20))
	Look.draw_text_centred(self, Vector2(x + suit_w / 2, 0), banner.suit, 13, Look.colour("ink", a), "SemiBold")
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _line_h(l: TallyLine) -> float:
	return (28.0 if l.style == "total" else 24.0)

func _tally_rect() -> Rect2:
	var h := 16.0
	for l in tally:
		h += _line_h(l)
	return Rect2(8, TALLY_TOP, Look.BOARD_W - 16, h)

## Where the total line's points sit, in this node's coordinates (set as the tally draws).
var _total_at := Vector2.ZERO
func _total_point() -> Vector2:
	return _total_at

## A tally too tall for the room below its top scales down to fit, from its top edge.
func _tally_scale(r: Rect2) -> float:
	var room := Look.BOARD_H - TALLY_TOP + 8
	return min(1.0, room / r.size.y)

func _draw_tally() -> void:
	var r := _tally_rect()
	var k := _tally_scale(r)
	var a := tally_in
	draw_set_transform(Vector2(size.x / 2, r.position.y), 0, Vector2(k, k))
	var box := Rect2(-r.size.x / 2, 0, r.size.x, r.size.y)
	draw_style_box(Look.box(Color(0, 0, 0, 0), 12, Color.TRANSPARENT, 0, Color(0, 0, 0, 0.45 * a), 10, Vector2(0, 8)), box)
	draw_style_box(Look.box(Look.colour("bg", 0.92 * a), 12, Look.colour("cyan", 0.35 * a), 1), box)
	var y := 8.0
	var left_x := box.position.x + 12
	var right_x := box.end.x - 12
	for l in tally:
		var lh := _line_h(l)
		var la: float = clamp(l.shown, 0.0, 1.0) * a
		var dx: float = -10.0 * (1.0 - clamp(l.shown, 0.0, 1.0))
		var total: bool = l.style == "total"
		var size_ := 20.0 if total else 16.0
		var weight := "Bold" if total else "Medium"
		if total:
			draw_rect(Rect2(box.position.x + 12, y, box.size.x - 24, 1), Look.colour("text", 0.3 * la))
		var mid := y + (lh + (4.0 if total else 0.0)) / 2
		if total:
			_total_at = Vector2(size.x / 2, r.position.y) + Vector2(box.end.x - 30, mid) * k
		Look.draw_text(self, Vector2(left_x + dx, Look.baseline_for_centre(mid, size_, weight)), l.name, size_, Look.colour("text", la), weight)
		var pts_w := 64.0 if total else 48.0
		var pw := Look.text_width(l.pts, size_, "Bold")
		Look.draw_text(self, Vector2(right_x - pw + dx, Look.baseline_for_centre(mid, size_, "Bold")), l.pts, size_, Color(_style_colour(l.style), la), "Bold")
		# Mini cards sit beside the points, right to left.
		var cx: float = right_x - pts_w - 6 + dx
		for i in range(l.cards.size() - 1, -1, -1):
			cx -= _mini(Vector2(cx, mid), l.cards[i], la) + 2
		y += lh
	if hold_in > 0.0:
		var t := "Tap to continue"
		var tw := Look.text_width(t, 13, "SemiBold") + 20
		var pill := Rect2(-tw / 2, box.end.y - 10, tw, 22)
		draw_style_box(Look.box(Look.colour("bg", hold_in), 11, Look.colour("cyan", 0.5 * hold_in), 1), pill)
		Look.draw_text_centred(self, pill.get_center(), t, 13, Look.colour("cyan", hold_in), "SemiBold")
	draw_set_transform_matrix(Transform2D.IDENTITY)

## A tally line's mini card, its right edge at `right`, centred on its y. Answers its width.
func _mini(right_mid: Vector2, notation: String, a: float) -> float:
	var c := CardArt.parse(notation)
	var text: String = c.rankText + {"S": "♠", "H": "♥", "D": "♦", "C": "♣"}[c.suit] if c.has("suit") else "★"
	var colour := Look.colour("card.suit." + c.suit) if c.has("suit") else Look.colour("ink")
	var w: float = max(22.0, Look.text_width(text, 12, "Bold", -0.3) + 4) + 4
	var r := Rect2(right_mid.x - w, right_mid.y - 13, w, 26)
	draw_style_box(Look.box(Look.colour("card.face", a), 3, Look.colour("gold", a) if c.kind == "made" else Look.colour("card.rule", a), 1), r)
	Look.draw_text_centred(self, r.get_center(), text, 12, Color(colour, a), "Bold", -0.3)
	return w

func _draw_row_card(rc: RowCard) -> void:
	var home := Board.frame(rc.p).get_center()
	var t := rc.t
	var at := home.lerp(_row_centre(rc.p), t) + Vector2(0, rc.lift)
	var k: float = lerp(1.0, ROW_W / Look.CARD_W, t)
	var rot: float = deg_to_rad(-5.0) * (1.0 - clamp(t, 0.0, 1.0)) if rc.p == 24 else 0.0
	var xf := Transform2D(rot, Vector2(k, k), 0, at)
	draw_set_transform_matrix(xf)
	var half := Vector2(Look.CARD_W, Look.CARD_H) / 2
	var rect := Rect2(-half, half * 2)
	var on := lit.has(rc.p) or power.has(rc.p) or left.has(rc.p)
	var ring := Look.colour("gold") if lit.has(rc.p) else (Look.colour("cyan") if power.has(rc.p) else (Look.colour("leftOver.ring") if left.has(rc.p) else Color.WHITE))
	if rc.glow > 0.01:
		var g := Color(ring, (0.85 if lit.has(rc.p) else 0.8) * rc.glow)
		draw_style_box(Look.box(Color(0, 0, 0, 0), Look.CARD_RADIUS, Color.TRANSPARENT, 0, g, 9), rect)
	else:
		draw_style_box(Look.box(Color(0, 0, 0, 0), Look.CARD_RADIUS, Color.TRANSPARENT, 0, Color(0, 0, 0, 0.4), 5, Vector2(0, 3)), rect)
	CardArt.draw(self, rect, rc.card, xf)
	var rw := 4.0 if on else 2.0
	draw_style_box(Look.box(Color.TRANSPARENT, Look.CARD_RADIUS + rw / 2, ring, rw), rect.grow(rw))
	# Tags and chips shrink with the card, upright (the Mac's RowCard scales them with it).
	draw_set_transform_matrix(Transform2D(0, Vector2(k, k), 0, at))
	var top := -half.y
	var right := half.x
	if rc.p == 24 and t > 0.5:
		var tag := "STARTER"
		var tw := Look.text_width(tag, 13, "Bold", 1) + 14
		var cx := -22.0 if chips.has(24) else 0.0
		var pill := Rect2(cx - tw / 2, top - 24 + 0, tw, 20)
		draw_style_box(Look.box(Look.colour("text"), 10), pill)
		Look.draw_text_centred(self, pill.get_center(), tag, 13, Look.colour("bg"), "Bold", 1)
	if chips.has(rc.p):
		var text: String = chips[rc.p]
		var cw := Look.text_width(text, 15, "Bold") + 14
		var pill := Rect2(right + 8 - cw, top - 8, cw, 22)
		draw_style_box(Look.box(Look.colour("cyan") if power.has(rc.p) else Look.colour("gold"), 11), pill)
		Look.draw_text_centred(self, pill.get_center(), text, 15, Look.colour("ink"), "Bold")
	draw_set_transform_matrix(Transform2D.IDENTITY)

## Points that pop over the cards and rise away (ui.md › Score breakdown › Layout, floats).
func _draw_float(f: Float) -> void:
	var F: Dictionary = Motion.wait("float")
	var keys: Array = F.keys
	var t := f.age / Motion.scale * 1000.0
	var k0: float = keys[0]
	var k1: float = k0 + float(keys[1])
	var k2: float = k1 + float(keys[2])
	var ease := func(a: float, b: float, x: float) -> float: return lerp(a, b, Motion._bezier(0.42, 0.0, 0.58, 1.0, x))
	var s: float
	var y: float
	var a: float
	if t < k0:
		var u := t / k0
		s = ease.call(F.startScale, F.peakScale, u)
		y = ease.call(F.startY, 0.0, u)
		a = ease.call(0.0, 1.0, u)
	elif t < k1:
		var u := (t - k0) / (k1 - k0)
		s = ease.call(F.peakScale, 1.0, u)
		y = ease.call(0.0, -F.midRise, u)
		a = 1.0
	else:
		var u: float = min(1.0, (t - k1) / (k2 - k1))
		s = 1.0
		y = ease.call(-F.midRise, -F.rise, u)
		a = ease.call(1.0, 0.0, u)
	var colour := Look.colour("cyan") if f.style == "power" else (Look.colour("leftOver.text") if f.style == "penalty" else Color.WHITE)
	draw_set_transform(f.at + Vector2(0, y), 0, Vector2(s, s))
	var shadow := Color(0, 0, 0, 0.7 * a)
	var sub_h := 18.0 if f.sub != "" else 0.0
	Look.draw_text_centred(self, Vector2(0, 2 - sub_h / 2), f.text, 30, shadow, "Bold")
	Look.draw_text_centred(self, Vector2(0, -sub_h / 2), f.text, 30, Color(colour, a), "Bold")
	if f.sub != "":
		Look.draw_text_centred(self, Vector2(0, 2 + 20), f.sub, 13, shadow, "SemiBold")
		Look.draw_text_centred(self, Vector2(0, 20), f.sub, 13, Color(colour, 0.9 * a), "SemiBold")
	draw_set_transform_matrix(Transform2D.IDENTITY)
