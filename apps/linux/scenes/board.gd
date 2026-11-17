class_name Board extends Control
## The board (ui.md › Board positions, Tracing a set): a 4 × 4 grid, the crib down the right, the
## hand along the bottom and the starter tilted in the corner, on one rounded edge background.
## Drag across touching cards to trace a set, or tap cards and tap the last one again.

var session: Session
var cells := {}        ## card id → Cell
var flash: Array = []  ## positions popping
var flash_bomb := false
## The breakdown's looks, set by the breakdown while it plays (Score breakdown).
var bd := {"active": false, "set": [], "lit": [], "power": [], "left": [], "row": [], "chips": {}, "pulse": []}

const HIT_FRACTION := 0.7   # ui.md › Hard-coded numbers 29: the drag hit area
const DRAG_START := 6.0     # ui.md › Hard-coded numbers 30

var _down := false
var _moved := false
var _start := Vector2.ZERO
var _layer: Node2D

func _init() -> void:
	custom_minimum_size = Vector2(Look.BOARD_W, Look.BOARD_H)
	size = custom_minimum_size
	mouse_filter = MOUSE_FILTER_STOP

func _ready() -> void:
	_layer = Node2D.new()
	add_child(_layer)
	session.turn_shown.connect(func(): _sync(false, [0, 0, 0, 0]))
	session.board_moved.connect(func(drawn): _sync(true, drawn))
	session.changed.connect(_restyle)
	session.pop.connect(func(ps, b): flash = ps; flash_bomb = b; _restyle())

## A position's name (g12, h0, c3, s) as its index (engine.md › Positions).
static func parse_pos(name: String) -> int:
	match name[0]:
		"g": return int(name[1]) * 4 + int(name[2])
		"h": return 16 + int(name.substr(1))
		"c": return 20 + int(name.substr(1))
	return 24

## Row and column on the board: grid (r, c), crib (i, 4), hand (4, i), starter (4, 4).
static func coords(p: int) -> Vector2i:
	if p < 16: return Vector2i(p / 4, p % 4)
	if p < 20: return Vector2i(4, p - 16)
	if p < 24: return Vector2i(p - 20, 4)
	return Vector2i(4, 4)

static func touching(a: int, b: int) -> bool:
	var x := coords(a)
	var y := coords(b)
	return a != b and abs(x.x - y.x) <= 1 and abs(x.y - y.y) <= 1

## A card's frame: the edge column and row are pushed out by the edge gap.
static func frame(p: int) -> Rect2:
	var rc := coords(p)
	var x := rc.y * Look.PITCH_X + (Look.EDGE_GAP if rc.y == 4 else 0.0)
	var y := rc.x * Look.PITCH_Y + (Look.EDGE_GAP if rc.x == 4 else 0.0)
	return Rect2(x, y, Look.CARD_W, Look.CARD_H)

# MARK: Cards

func _sync(animate: bool, drawn: Array) -> void:
	var t := session.turn
	if t.is_empty():
		for id in cells:
			cells[id].queue_free()
		cells.clear()
		queue_redraw()
		return
	var keep := {}
	var change := Motion.spec("board.change")
	for p in 25:
		var ref = t.cells[p]
		if ref == null:
			continue
		var id := int(ref.id)
		keep[id] = true
		var home := frame(p).get_center()
		var c: Cell = cells.get(id)
		if c == null:
			c = Cell.new()
			c.session = session
			c.ref = ref
			c.pos = p
			cells[id] = c
			_layer.add_child(c)
			if animate and p < 16:
				# Drawn cards drop in from above, as many card heights as cards were drawn into the column.
				c.home = home - Vector2(0, max(1, drawn[p % 4]) * Look.PITCH_Y)
				c.fade = 0.0
				Motion.animate(c, "home", home, change)
				Motion.animate(c, "fade", 1.0, change)
			else:
				c.home = home
		else:
			c.ref = ref
			c.pos = p
			if animate and c.home != home:
				Motion.animate(c, "home", home, change)
			else:
				Motion.snap(c, "home", home)
	for id in cells.keys():
		if not keep.has(id):
			var c: Cell = cells[id]
			cells.erase(id)
			if animate:
				# Cleared cards shrink to 20% and fade.
				c.z_index = 2
				Motion.animate(c, "vanish", 0.2, change)
				Motion.animate(c, "fade", 0.0, change).finished.connect(c.queue_free)
			else:
				c.queue_free()
	_restyle()
	queue_redraw()

func _restyle() -> void:
	var lit := session.lit_positions()
	var s := session.turn
	for id in cells:
		var c: Cell = cells[id]
		var p := c.pos
		c.order = session.selection.find(p)
		c.used = lit.has(p)
		c.hit = flash.has(p)
		c.bomb = flash_bomb
		c.inset = bd.set.has(p)
		c.dimmed = bd.active and not bd.set.is_empty() and not c.inset
		c.lit = bd.lit.has(p)
		c.lit_power = bd.power.has(p)
		c.left = bd.left.has(p)
		c.away = bd.row.has(p)
		c.armed = session.armed_source == p
		var level: int = bd.chips.get(p, int(s.power[p])) if p >= 16 and not s.is_empty() else 0
		if level > 0:
			c.chip = session.multiplier_text(level)
		elif c.ref.has("percent"):
			c.chip = Session.multiplier_percent(int(c.ref.percent))
		else:
			c.chip = ""
		c.chip_pulse = bd.pulse.has(p)
		c.apply_look()
	mouse_default_cursor_shape = CURSOR_CROSS if session.mode in ["bomb", "burn"] else CURSOR_ARROW

# MARK: Drawing the board

func _edge_polygon(dealer: bool) -> PackedVector2Array:
	var pad := Look.EDGE_PAD
	var outer := Look.EDGE_PAD_OUTER
	var r := Look.CARD_RADIUS + pad
	var grow := func(f: Rect2) -> Rect2: return Rect2(f.position - Vector2(pad, pad), f.size + Vector2(pad + outer, pad + outer))
	var row: Rect2 = grow.call(frame(16).merge(frame(24)))
	var poly := Look.rounded_outline(row, r)
	if dealer:
		var col: Rect2 = grow.call(frame(20).merge(frame(24)))
		var merged := Geometry2D.merge_polygons(poly, Look.rounded_outline(col, r))
		for m in merged:
			if not Geometry2D.is_polygon_clockwise(m):
				return m
		return merged[0]
	return poly

func _draw() -> void:
	var dealer: bool = session.turn.get("dealer", true)
	var poly := _edge_polygon(dealer)
	draw_colored_polygon(poly, Look.colour("panel"))
	var closed := poly.duplicate()
	closed.append(poly[0])
	draw_polyline(closed, Look.colour("cyan", 0.12), 5.0, true)
	draw_polyline(closed, Look.colour("cyan", 0.5), 1.0, true)
	# The starter counts with every set (r16), so it sits on a lighter bed of its own.
	var sf := frame(24).grow(Look.EDGE_PAD + 3)
	draw_style_box(Look.box(Look.colour("starterBed"), Look.CARD_RADIUS + 8, Look.colour("text", 0.6), 1.5), sf)
	var empty := Look.colour("text", 0.25)
	for p in 25:
		var f := frame(p)
		Look.draw_dashed(self, Look.rounded_outline(f.grow(-0.5), Look.CARD_RADIUS), empty, 1.0, 4.0, 3.0)
		if p >= 20 and p < 24 and not dealer:
			Look.draw_text_centred(self, f.get_center(), "no crib", 11, Look.colour("text", 0.5), "SemiBold")

# MARK: Input (ui.md › Tracing a set)

func _hit(pt: Vector2, strict: bool) -> int:
	for p in 25:
		if session.cell(p) == null:
			continue
		var f := frame(p)
		var s := HIT_FRACTION if strict else 1.0
		if f.grow_individual(-f.size.x * (1 - s) / 2, -f.size.y * (1 - s) / 2, -f.size.x * (1 - s) / 2, -f.size.y * (1 - s) / 2).has_point(pt):
			return p
	return -1

## A word tag under a point: tapping HAND, CRIB or STARTER explains it.
func _tag_hit(pt: Vector2) -> String:
	for pair in [[16, "hand"], [20, "crib"], [24, "starter"]]:
		if session.cell(pair[0]) == null:
			continue
		var f := frame(pair[0])
		if Rect2(f.get_center().x - 40, f.position.y - 20, 80, 24).has_point(pt):
			return pair[1]
	return ""

## Whether a card fits under the pick limit (a joining starter is free).
func _can_add(p: int, sel: Array[int]) -> bool:
	if p == 24 and session.turn.starterJoins:
		return true
	return sel.filter(func(x): return not (x == 24 and session.turn.starterJoins)).size() < session.pick_limit()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			if session.blocked:
				return
			_down = true
			_moved = false
			_start = e.position
		elif _down:
			_down = false
			_ended(e.position)
		accept_event()
	elif e is InputEventMouseMotion and _down:
		_changed(e.position)
		accept_event()

func _changed(at: Vector2) -> void:
	if session.blocked:
		return
	if not _moved and at.distance_to(_start) > DRAG_START:
		_moved = true
		# A drag starts a fresh trace from the card it began on.
		var first := _hit(_start, false)
		var fresh: Array[int] = []
		if first >= 0:
			fresh.append(first)
		session.set_selection(fresh)
	if not _moved:
		return
	var p := _hit(at, true)
	if p < 0:
		return
	var sel: Array[int] = session.selection.duplicate()
	if sel.is_empty():
		sel = [p]
	elif sel.size() >= 2 and sel[sel.size() - 2] == p:
		sel.pop_back()   # back up
	elif not sel.has(p) and touching(sel.back(), p) and _can_add(p, sel):
		sel.append(p)
	session.set_selection(sel)

func _ended(at: Vector2) -> void:
	var none: Array[int] = []
	if session.blocked:
		session.set_selection(none)
		return
	if _moved:
		var sel := session.selection.duplicate()
		session.set_selection(none)
		if sel.size() >= 2:
			session.submit(sel)
		return
	var topic := _tag_hit(at)
	if topic != "":
		session.set_selection(none)
		session.info = topic
		return
	var p := _hit(at, false)
	if p < 0:
		session.set_selection(none)
		return
	_tap(p, session.cell(p))

func _tap(p: int, card: Dictionary) -> void:
	var none: Array[int] = []
	var sel: Array[int] = session.selection.duplicate()
	if session.mode in ["bomb", "burn"]:
		session.set_selection(none)
		session.submit([p] as Array[int])
		return
	var c := CardArt.parse(card.card)
	if c.kind == "special" and session.mode == "trace":
		session.set_selection(none)
		session.arm(c.name, p)
		return
	if not sel.is_empty() and sel.back() == p:
		session.set_selection(none)
		if sel.size() >= 2:
			session.submit(sel)
		return
	var i := sel.find(p)
	if i >= 0:
		sel.resize(i)
	elif sel.is_empty() or touching(sel.back(), p):
		if not _can_add(p, sel):
			session.show_toast("A set picks %d cards at most" % session.pick_limit())
			return
		sel.append(p)
	else:
		sel = [p]
	session.set_selection(sel)
