class_name Parts
## The match turn screen's smaller parts (ui.md › The match turn screen), each a Control that
## draws itself from the session.

## Steps, the stock and the progress track (ui.md › The match turn screen).
class Header extends Control:
	var session: Session
	var shown_steps := 0.0
	var track_steps := 0.0
	var bump := 0.0   ## 0 to 1: the steps number turning gold and growing after a breakdown
	var _steps := 0
	var _bumped := false
	const NUMBER := 44.0
	const LABEL := 13.0

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_STOP
		session.changed.connect(_refresh)
		session.turn_shown.connect(func():
			_steps = int(session.turn.get("steps", 0))
			Motion.snap(self, "shown_steps", float(_steps))
			Motion.snap(self, "track_steps", float(_steps))
			queue_redraw())

	func number_height() -> float:
		var f := Look.font("Bold")
		return f.get_height(int(NUMBER))

	func row_height() -> float:
		var f := Look.font("Medium")
		return max(number_height() + 2 + f.get_height(int(LABEL)), Look.CARD_W * 46.0 / 64.0 * 1.4)

	## Where the steps number sits on the phone, for the total's flight in a breakdown.
	func steps_point() -> Vector2:
		return global_position + Vector2(24, number_height() / 2)

	func _refresh() -> void:
		var s := int(session.turn.get("steps", 0))
		if s != _steps:
			_steps = s
			Motion.animate(self, "shown_steps", float(s), Motion.spec("board.numberRoll"), true, self)
			Motion.animate(self, "track_steps", float(s), Motion.spec("board.stepsCount"), true, self)
		if session.bump != _bumped:
			_bumped = session.bump
			Motion.animate(self, "bump", 1.0 if _bumped else 0.0, Motion.spec("board.stepsBump" if _bumped else "board.stepsUnbump"), true, self)
		queue_redraw()

	func _draw() -> void:
		var text := Look.colour("text")
		var gold := Look.colour("gold")
		var f := Look.font("Bold")
		var n := str(int(round(shown_steps)))
		var base_y := f.get_ascent(int(NUMBER))
		var k := 1.0 + 0.25 * bump
		draw_set_transform(Vector2(0, number_height() / 2), 0, Vector2(k, k))
		Look.draw_text(self, Vector2(0, base_y - number_height() / 2), n, NUMBER, text.lerp(gold, clamp(bump, 0, 1)), "Bold")
		draw_set_transform_matrix(Transform2D.IDENTITY)
		var fm := Look.font("Medium")
		Look.draw_text(self, Vector2(0, number_height() + 2 + fm.get_ascent(int(LABEL))), "steps scored", LABEL, Look.colour("text", 0.75), "Medium")
		# The stock, face down, its count on a gold badge; a dashed outline once it runs out.
		var w := 46.0
		var card := Rect2(size.x - w - 8, (row_height() - w * 1.4) / 2, w, w * 1.4)
		var left := int(session.turn.get("drawable", 0))
		if left > 0:
			CardArt.draw(self, card, "back")
			var label := str(left)
			var bw: float = max(24.0, Look.text_width(label, 13, "Bold") + 10)
			var centre := card.end + Vector2(8, 6) - Vector2(bw / 2, 11)
			var badge := Rect2(centre - Vector2(bw / 2, 11), Vector2(bw, 22))
			draw_style_box(Look.box(gold, 11, Color.TRANSPARENT, 0, Look.colour("gold", 0.5), 3), badge)
			Look.draw_text_centred(self, badge.get_center(), label, 13, Look.colour("ink"), "Bold")
		else:
			Look.draw_dashed(self, Look.rounded_outline(card.grow(-0.5), 5), Look.colour("text", 0.25), 1, 4, 3)
		# The progress track: this turn's steps against 121 (ui.md › Hard-coded numbers 28).
		var ty := row_height() + 10
		var track := Rect2(0, ty, size.x, 6)
		draw_style_box(Look.box(Look.colour("text", 0.15), 3), track)
		var share: float = clamp(track_steps / 121.0, 0.0, 1.0)
		if share > 0:
			draw_style_box(Look.box(gold, 3, Color.TRANSPARENT, 0, Look.colour("gold", 0.7), 3), Rect2(0, ty, max(6.0, size.x * share), 6))

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			pass   # the settings panel opens here; not built yet (apps/linux/README.md › Status)

## The line under the board: what the trace would do, or what a joker or a stuck board needs.
class HelpLine extends RichTextLabel:
	var session: Session
	func _ready() -> void:
		bbcode_enabled = false
		scroll_active = false
		autowrap_mode = TextServer.AUTOWRAP_OFF
		clip_contents = true
		mouse_filter = MOUSE_FILTER_IGNORE
		session.changed.connect(_refresh)
	func _refresh() -> void:
		var text := session.help_line()
		var stuck := session.dead and session.selection.is_empty() and session.mode == "trace"
		var colour := Look.colour("gold") if stuck else Look.colour("text", 0.9)
		var weight := "SemiBold" if stuck else "Medium"
		# One line: shrink to 75% before it's cut short.
		var s := 14.0
		while s > 14.0 * 0.75 and Look.text_width(text, s, weight) > size.x:
			s -= 0.5
		Look.rich(self, text, s, colour, weight)

## The power jokers panel (ui.md › Power jokers): one slot per known kind, at least 4.
class Tray extends Control:
	var session: Session
	var slots: Array[TrayCard] = []
	var blink := 0.0
	const TAG := "POWER JOKERS"

	func _ready() -> void:
		var known: Array = session.rules.specials.known
		for i in max(4, known.size()):
			var t := TrayCard.new()
			t.session = session
			t.kind = known[i] if i < known.size() else ""
			add_child(t)
			slots.append(t)
		session.changed.connect(queue_redraw)
		resized.connect(_layout)
		_layout()

	func _layout() -> void:
		var inner := size.x - 16
		var each := inner / slots.size()
		for i in slots.size():
			slots[i].position = Vector2(8 + each * i + (each - 72) / 2, 20)
			slots[i].size = Vector2(72, 72 * 1.4)

	func tag_rect() -> Rect2:
		var w := Look.text_width(TAG, 10, "Bold", 0.8) + 12
		return Rect2(size.x / 2 - w / 2, -8, w, 16)

	func _draw() -> void:
		draw_style_box(Look.box(Look.colour("panel"), 12, Look.colour("joker.special", 0.5), 1), Rect2(Vector2.ZERO, size))
		var tr := tag_rect()
		draw_style_box(Look.box(Look.colour("joker.special"), 8), tr)
		Look.draw_text_centred(self, tr.get_center(), TAG, 10, Look.colour("bg"), "Bold", 0.8)

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			if tag_rect().grow(4).has_point(e.position) and not session.blocked:
				session.info = "tray"
				accept_event()

## One tray slot: the joker card, a stack when you hold 2 or more, its count, armed and reach looks.
class TrayCard extends Control:
	var session: Session
	var kind := ""
	var raise := 0.0
	var _armed := false
	const W := 72.0

	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_STOP
		tooltip_text = {"swapper": "Swapper: reverses a straight line of 2 to 4 grid cards",
			"bomb": "Bomb: clears a card and its neighbours, without scoring",
			"reach": "Reach: hand size +1 (sometimes +2) for about 20 seconds",
			"burn": "Burn: takes a grid card out of the deck for the rest of the game",
			"": "An empty slot for a power joker you haven't found yet"}.get(kind, kind)
		session.changed.connect(_refresh)

	func _refresh() -> void:
		var armed: bool = kind != "" and Session.ARMS.get(kind, "") == session.mode and session.armed_source < 0
		if armed != _armed:
			_armed = armed
			Motion.animate(self, "raise", -10.0 if armed else 0.0, Motion.spec("board.select"), true, self)
		queue_redraw()

	func _draw() -> void:
		var rect := Rect2(0, raise, W, W * 1.4)
		if kind == "":
			draw_style_box(Look.box(Look.colour("bg", 0.5), 6), rect)
			Look.draw_dashed(self, Look.rounded_outline(rect.grow(-0.75), 6), Look.colour("joker.special", 0.35), 1.5, 5, 4)
			return
		var count := int(session.turn.get("tray", {}).get(kind, 0))
		var countdown := session.reach_fraction() if kind == "reach" else -1.0
		var a := 0.3 if count < 1 and countdown < 0 else 1.0
		if count > 1:
			draw_style_box(Look.box(Color(Look.colour("card.stack.0"), a), 5), Rect2(rect.position + Vector2(6, -6), rect.size))
			draw_style_box(Look.box(Color(Look.colour("card.stack.1"), a), 5), Rect2(rect.position + Vector2(3, -3), rect.size))
		if _armed:
			draw_style_box(Look.box(Color(0, 0, 0, 0), 5, Color.TRANSPARENT, 0, Color(0, 0, 0, 0.4), 6, Vector2(0, 6)), rect)
		CardArt.draw(self, rect, kind, Transform2D.IDENTITY, Color(1, 1, 1, a))
		if _armed:
			draw_style_box(Look.box(Color.TRANSPARENT, 6.5, Color.WHITE, 3), rect.grow(3))
		if countdown >= 0:
			draw_style_box(Look.box(Look.colour("bg", 0.55), 5), rect)
			var c := rect.get_center()
			var r := W * 0.62 / 2
			draw_circle(c, r + 4, Look.colour("joker.special", 0.15), true, -1, true)
			draw_circle(c, r, Look.colour("bg", 0.6), true, -1, true)
			Parts.wedge(self, c, r, countdown, Look.colour("joker.special"))
			draw_arc(c, r - 1.25, 0, TAU, 48, Look.colour("joker.special"), 2.5, true)
		# The count, on a violet badge at the bottom right.
		var label := str(count)
		var bw: float = max(20.0, Look.text_width(label, 12, "Bold") + 10)
		var badge := Rect2(rect.end + Vector2(6, 6) - Vector2(bw, 20), Vector2(bw, 20))
		draw_style_box(Look.box(Color(Look.colour("joker.special"), a), 10, Color.TRANSPARENT, 0, Look.colour("joker.special", 0.6 * a), 3), badge)
		Look.draw_text_centred(self, badge.get_center(), label, 12, Look.colour("bg"), "Bold")

	func _gui_input(e: InputEvent) -> void:
		if kind == "" or not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
			return
		accept_event()
		if kind == "reach":
			if not session.over and int(session.turn.tray.get(kind, 0)) > 0 and session.mode == "trace":
				session.arm(kind)
		else:
			session.tap_tray(kind)

## A pie wedge from 12 o'clock, clockwise.
static func wedge(ci: CanvasItem, c: Vector2, r: float, fraction: float, colour: Color) -> void:
	if fraction <= 0.0:
		return
	var pts := PackedVector2Array([c])
	var n := 48
	for i in n + 1:
		var a: float = -PI / 2 + TAU * min(1.0, fraction) * i / n
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	ci.draw_colored_polygon(pts, colour)

## The footer's pick counter (ui.md › The pick counter): one pip per card a set may pick.
class PickCounter extends Control:
	var session: Session
	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_STOP
		tooltip_text = "Hand size: how many cards a set can pick. The starter is free."
		session.changed.connect(queue_redraw)
	func _draw() -> void:
		var limit := session.pick_limit()
		var count := session.picked_count() if session.mode == "trace" else 0
		var extra := limit - int(session.rules.match.maxSet)
		var full := count == limit
		for i in limit:
			var added := i >= limit - extra
			var r := Rect2(i * 13.0, 0, 9, 13)
			var fill: Color
			if i < count:
				fill = Look.colour("gold") if full else Look.colour("cyan")
			else:
				fill = Look.colour("joker.special", 0.35) if added else Look.colour("text", 0.14)
			var line := Look.colour("joker.special") if added else Look.colour("text", 0.0 if i < count else 0.3)
			draw_style_box(Look.box(fill, 2, line, 1.5 if added else 1.0), r)
		var f := Look.font("Bold")
		Look.draw_text(self, Vector2(0, 13 + 4 + f.get_ascent(11)), "HAND SIZE %d / %d" % [count, limit], 11,
			Look.colour("gold") if full else Look.colour("text", 0.75), "Bold", 0.6)
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			if not session.blocked:
				session.info = "counter"

## The turn clock (ui.md › The turn clock).
class Clock extends Control:
	var session: Session
	var filled := 0.0
	var colour := Color.WHITE
	var _look := ""
	var _target := -1.0
	var _breath := 0.0      # seconds into the current breath
	var _urgency := -1
	var _pulse := 0.0
	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		session.changed.connect(_refresh)
		session.turn_shown.connect(func(): _target = -1.0; _refresh())
	func _look_now() -> String:
		var total := int(session.turn.get("timerSeconds", 0))
		if session.over: return "done"
		if session.grace_left >= 0: return "stuck"
		if total == 0: return "off"
		if session.seconds_left * 100 <= total * int(Motion.wait("clock.warningPercent")): return "warning"
		return "running"
	func _refresh() -> void:
		var look := _look_now()
		var total := int(session.turn.get("timerSeconds", 0))
		var f := 0.0
		match look:
			"done": f = 1.0
			"stuck": f = 1.0 - float(session.grace_left) / Session.GRACE_SECONDS
			"off": f = 0.0
			_: f = 1.0 - float(max(0, session.seconds_left)) / total if total > 0 else 0.0
		if f != _target:
			if _target < 0:
				Motion.snap(self, "filled", f)
			else:
				Motion.animate(self, "filled", f, Motion.spec("clock.wedge"), false, self)   # grows smoothly between ticks
			_target = f
		var c: Color = {"running": Look.colour("clock.green"), "warning": Look.colour("clock.orange"), "stuck": Look.colour("clock.orange"),
			"done": Look.colour("clock.red"), "off": Look.colour("text", 0.3)}[look]
		if look != _look:
			if _look == "":
				colour = c
			else:
				Motion.animate(self, "colour", c, Motion.spec("clock.look"), false, self)
			_look = look
			_pulse = 0.0
		var level := _urgency_now(total) if look in ["running", "warning"] else -1
		if level != _urgency:
			_urgency = level
			_breath = 0.0
		queue_redraw()
	func _urgency_now(total: int) -> int:
		if total <= 0: return 0
		var share: float = float(max(0, session.seconds_left)) / total
		var u: Array = Motion.wait("clock.urgencyPercent")
		if share > u[0] / 100.0: return 0
		if share > u[1] / 100.0: return 1
		if share > u[2] / 100.0: return 2
		return 3
	func _process(delta: float) -> void:
		if _urgency >= 0 or _look == "stuck":
			_breath += delta
			_pulse += delta
			queue_redraw()
	## easeInOut back and forth: 0 → 1 → 0 over two half-lengths.
	func _wave(t: float, half: float) -> float:
		var s := {"type": "easeInOut", "ms": half * 1000.0}
		var k := fmod(t, 2 * half)
		return Motion.at(s, k) if k < half else 1.0 - Motion.at(s, k - half)
	func _draw() -> void:
		var k := 1.0
		if _urgency >= 0:
			var depth: float = Motion.wait("clock.breathDepth")[_urgency]
			var half: float = Motion.wait("clock.halfBreath")[_urgency] / 1000.0
			k = lerp(1.0 - depth / 2, 1.0 + depth, _wave(_breath, half))
		var a := 1.0
		if _look == "stuck":
			a = lerp(1.0, 0.35, _wave(_pulse, Motion.spec("clock.pulse").ms / 1000.0))
		var c := size / 2
		draw_set_transform(c, 0, Vector2(k, k))
		var col := Color(colour, colour.a * a)
		if _look != "off":
			draw_circle(Vector2.ZERO, 19, Color(colour, 0.12 * a), true, -1, true)
		draw_circle(Vector2.ZERO, 15, Color(colour, 0.15 * a), true, -1, true)
		Parts.wedge(self, Vector2.ZERO, 15, filled, col)
		draw_arc(Vector2.ZERO, 14, 0, TAU, 48, col, 2.0, true)
		var secs := session.seconds_left
		if _look in ["running", "warning"] and secs <= int(Motion.wait("clock.secondsFrom")):
			Look.draw_text_centred(self, Vector2(0.5, 1), str(max(0, secs)), 14, Color(0, 0, 0, 0.6), "Bold")
			Look.draw_text_centred(self, Vector2.ZERO, str(max(0, secs)), 14, Color.WHITE, "Bold")
		draw_set_transform_matrix(Transform2D.IDENTITY)

## The gold toast over the middle of the screen (ui.md › Overlays).
class Toast extends Control:
	var session: Session
	var text := ""
	var shown := 0.0
	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		session.toast_changed.connect(_refresh)
	func _refresh() -> void:
		if session.toast != "":
			text = session.toast
		Motion.animate(self, "shown", 1.0 if session.toast != "" else 0.0, Motion.spec("board.helpText"), true, self)
	func _draw() -> void:
		if shown <= 0.0 or text == "":
			return
		var maxw := size.x - 40 - 36
		var lines := _wrap(text, maxw)
		var f := Look.font("Bold")
		var lh := f.get_height(20)
		var w := 0.0
		for l in lines:
			w = max(w, Look.text_width(l, 20, "Bold"))
		var box := Vector2(w + 36, lh * lines.size() + 20)
		var c := Vector2(size.x / 2, size.y * 0.46)
		var k := 0.9 + 0.1 * shown
		draw_set_transform(c, 0, Vector2(k, k))
		draw_style_box(Look.box(Look.colour("gold", shown), 12), Rect2(-box / 2, box))
		for i in lines.size():
			Look.draw_text_centred(self, Vector2(0, -box.y / 2 + 10 + lh * (i + 0.5)), lines[i], 20, Look.colour("ink", shown), "Bold")
		draw_set_transform_matrix(Transform2D.IDENTITY)
	func _wrap(t: String, maxw: float) -> Array:
		var out := []
		var line := ""
		for word in t.split(" "):
			var next := word if line == "" else line + " " + word
			if Look.text_width(next, 20, "Bold") > maxw and line != "":
				out.append(line)
				line = word
			else:
				line = next
		out.append(line)
		return out
