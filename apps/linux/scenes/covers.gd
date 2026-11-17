class_name Covers
## What covers the match turn: the left-over warning, the info cards and the turn summary
## (ui.md › Overlays, Scene: Turn summary). Built from plain Controls in Saira.

static func _rich(text: String, size: float, colour: Color, weight := "Regular", width := 0.0) -> RichTextLabel:
	var l := RichTextLabel.new()
	l.fit_content = true
	l.scroll_active = false
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_constant_override("line_separation", 3)
	if width > 0:
		l.custom_minimum_size.x = width
	Look.rich(l, text, size, colour, weight)
	return l

static func _button(text: String, fill: Color, ink: Color, action: Callable, outline := Color.TRANSPARENT) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", Look.font("SemiBold"))
	b.add_theme_font_size_override("font_size", 15)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, ink)
	var normal := Look.box(fill, 10, outline, 1.0 if outline.a > 0 else 0.0)
	normal.content_margin_top = 9
	normal.content_margin_bottom = 9
	var hover := normal.duplicate()
	hover.bg_color = fill.lightened(0.08) if fill.a > 0 else Color(1, 1, 1, 0.06)
	hover.draw_center = true
	for state in ["normal", "focus", "disabled"]:
		b.add_theme_stylebox_override(state, normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.pressed.connect(action)
	return b

## A black wash over the phone, with a card on it. A tap on the wash calls `outside`, if given.
static func _wash(outside := Callable()) -> Control:
	var wash := ColorRect.new()
	wash.color = Color(0, 0, 0, 0.25)
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_STOP
	if outside.is_valid():
		wash.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				outside.call())
	return wash

static func _card(parent: Control, width: float, fill: Color, radius: float, shadow: Color, shadow_size: float, shadow_y: float, pad: Vector4) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := Look.box(fill, radius, Color.TRANSPARENT, 0, shadow, shadow_size, Vector2(0, shadow_y))
	style.content_margin_left = pad.x
	style.content_margin_top = pad.y
	style.content_margin_right = pad.z
	style.content_margin_bottom = pad.w
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size.x = width
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.add_child(panel)
	parent.add_child(centre)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	return v

## The first-time left-over warning; play waits for "Got it".
static func warning(left: Array, cost: int, done: Callable) -> Control:
	var root := _wash()
	var ink := Look.colour("ink")
	var w := Look.PHONE_W - 40
	var v := _card(root, w, Look.colour("paper"), 16, Color(0, 0, 0, 0.55), 16, 12, Vector4(18, 18, 18, 14))
	var inner := w - 36
	v.add_child(_rich("Every card must score", 22, ink, "Bold", inner))
	v.add_child(_rich("A set can hold one combo or several (7-8-8 is two fifteens and a pair), but every card you trace must be part of at least one: a fifteen, pair, run, flush or his nobs.", 15, ink, "Regular", inner))
	var names := RichTextLabel.new()
	names.fit_content = true
	names.scroll_active = false
	names.custom_minimum_size.x = inner
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.add_theme_constant_override("line_separation", 3)
	names.push_font(Look.font("Regular"), 15)
	names.push_color(ink)
	names.add_text("Here, ")
	names.pop()
	names.pop()
	_append(names, " ".join(left), 15, Look.colour("leftOver.names"), "Bold")
	names.push_font(Look.font("Regular"), 15)
	names.push_color(ink)
	names.add_text((" isn't" if left.size() == 1 else " aren't") + " part of any combo. While you trace, only cards in a combo light up.")
	names.pop_all()
	v.add_child(names)
	var rule := RichTextLabel.new()
	rule.fit_content = true
	rule.scroll_active = false
	rule.custom_minimum_size.x = inner
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.add_theme_constant_override("line_separation", 3)
	_append(rule, "From now on, a set still scores its combos, but each card left over costs %d step%s." % [cost, "" if cost == 1 else "s"], 15, ink, "Bold")
	_append(rule, " Your steps can go below 0. This time nothing happens.", 15, ink, "Regular")
	v.add_child(rule)
	var b := _button("Got it", Look.colour("bg"), Look.colour("text"), done)
	var gap := Control.new()
	gap.custom_minimum_size.y = 0
	v.add_child(gap)
	v.add_child(b)
	return root

static func _append(l: RichTextLabel, text: String, size: float, colour: Color, weight: String) -> void:
	l.push_font(Look.font(weight), int(size))
	l.push_color(colour)
	var run := ""
	for ch in text:
		if Look.MARK_CHARS.has(ch):
			l.add_text(run)
			run = ""
			var s := int(round(size * 0.8))
			l.add_image(Look.mark(Look.MARK_CHARS[ch]), s, s, colour, INLINE_ALIGNMENT_BOTTOM_TO | INLINE_ALIGNMENT_TO_BASELINE)
		else:
			run += ch
	l.add_text(run)
	l.pop()
	l.pop()

## An info card over the board: a title and a few lines (ui.md › Overlays).
static func info(topic: String, session: Session, done: Callable) -> Control:
	var root := _wash(done)
	var ink := Look.colour("ink")
	var v := _card(root, 340, Look.colour("card.face"), 14, Color(0, 0, 0, 0.4), 14, 8, Vector4(18, 18, 18, 18))
	var t := info_text(topic, session)
	v.add_child(_rich(t[0], 22, ink, "Bold", 304))
	for line in t[1]:
		v.add_child(_rich(line, 15, ink, "Medium", 304))
	v.add_child(_button("Got it", Look.colour("bg"), Look.colour("text"), done))
	return root

static func info_text(topic: String, session: Session) -> Array:
	var ep: Dictionary = session.rules.match.edgePower
	var pct := int(ep.percentPerLevel)
	var cap := int(ep.capPercent)
	var power := "Each time it scores, it powers up: every level multiplies the sets it's in by another ×%s%s." % [
		Session.multiplier_percent(100 + pct).substr(1), (", up to " + Session.multiplier_percent(cap)) if cap > 0 else ", with no limit"]
	match topic:
		"hand":
			return ["Your hand", ["The 4 cards you kept from the deal. They're edge cards: they stay all turn and never clear.",
				"Trace them with grid cards that touch them. " + power]]
		"crib":
			return ["The crib", ["The crib is the dealer's. On your turns as dealer, its 4 cards sit down this side." if not session.turn.get("dealer", true)
				else "The dealer's crib: 4 more edge cards down the side. Like your hand, they stay all turn and never clear.",
				"Trace them with grid cards that touch them. " + power]]
		"starter":
			return ["The starter", ["As in a cribbage hand, the starter counts with every set you score. You don't have to trace it, and it never counts toward your cards.",
				"When it's part of a combo it lights up and scores, and it's never left over when it isn't.", power]]
		"tray":
			return ["Power jokers", ["Special jokers you've won, kept all game.",
				"Swapper: tap it, then trace a straight line of 2 to 4 grid cards to reverse it.",
				"Bomb: tap it, then tap a grid card. It clears that card and its neighbours, without scoring.",
				"Reach: tap it to raise your hand size, the cards a set can pick, usually by 1 for about 20 seconds. The countdown shows on the card, and the extra cards show in violet on the card counter.",
				"Tap an armed joker again to put it back."]]
	return ["Hand size", ["Your hand size is how many cards a set can pick: 2 to %d now. The pips fill as you pick, and turn gold at the limit." % session.pick_limit(),
		"The starter is free: it joins every set without using a pip.",
		"A reach joker raises your hand size for a while: its extra pips are violet, and its countdown shows on the reach card. Later, some combos and prizes may raise it too."]]

## The end-of-turn summary, over the whole phone (ui.md › Scene: Turn summary).
static func summary(session: Session) -> Control:
	var root := ColorRect.new()
	root.color = Look.colour("bg", 0.95)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 24)
	m.add_theme_constant_override("margin_right", 24)
	m.add_theme_constant_override("margin_top", 56)
	m.add_theme_constant_override("margin_bottom", 24)
	root.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)
	var g := session.game
	var t: Dictionary = session.turn.get("totals", {})
	var text := Look.colour("text")
	var head := Look.label("GAME OVER" if g.over else "TURN %d OF %d" % [g.results.size(), g.turns], 11, Look.colour("text", 0.7), "Bold")
	v.add_child(head)
	var title := Look.label({"player": "Turn over", "timer": "Time's up", "board_cleared": "Board cleared!"}.get(session.turn.get("endReason", ""), "Turn over"), 24, Look.colour("cyan"), "Bold")
	v.add_child(title)
	v.add_child(Look.label("%d steps" % int(session.turn.get("steps", 0)), 48, Look.colour("gold"), "Bold"))
	var grid := GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 3)
	var row := func(a: String, b: String):
		var l := Look.label(a, 15, text, "Regular")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(l)
		var r := Look.label(b, 15, text, "SemiBold")
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(r)
	if not t.is_empty():
		row.call("Sets scored", str(int(t.scores)))
		row.call("Best set", str(int(t.best)) if t.get("best") != null else "none")
		row.call("Steps from edge power", _signed(int(t.stepsFromEdgePower)))
		row.call("Cards left over", _signed(-(int(t.leftOverTotal) + int(t.penaltyTotal))))
		if int(t.clearBonus) > 0:
			row.call("Clear-board bonus", "+%d" % int(t.clearBonus))
		row.call("Swaps, bombs, burns", "%d, %d, %d" % [int(t.swaps), int(t.bombs), int(t.burns)])
		if g.results.size() > 1:
			row.call("Game so far", "%d steps" % int(g.steps))
	v.add_child(grid)
	for e in session.events:
		if e.has("prizeWon"):
			var p: Dictionary = e.prizeWon
			var prize := Look.label("%s prize: a %s%s" % [p.tier.capitalize(), p.special, ", for your power jokers" if session.more_turns else ""], 17, Look.colour("gold"), "SemiBold")
			prize.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(prize)
	var last: Dictionary = g.results.back() if g.results.size() > 0 else {}
	var deck := DeckPanel.new()
	deck.game = g
	deck.new_made = last.get("made", []).map(func(c): return int(c.id))
	deck.new_burned = last.get("burned", []).map(func(c): return int(c.id))
	v.add_child(deck)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	if session.more_turns:
		var b := _button("Next turn", text, Look.colour("bg"), session.next_turn)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(b)
	else:
		var same := _button("Same seed", Color.TRANSPARENT, text, func(): session.new_game(session.seed), Look.colour("text", 0.4))
		same.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(same)
		var fresh := _button("New game", text, Look.colour("bg"), func(): session.new_game())
		fresh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(fresh)
	v.add_child(buttons)
	return root

static func _signed(n: int) -> String:
	return "+%d" % n if n > 0 else ("−%d" % -n if n < 0 else "0")

## The deck as it stands: its size, the cards made into it and burned out of it (ui.md › The deck).
class DeckPanel extends Control:
	var game := {}
	var new_made: Array = []
	var new_burned: Array = []
	var compact := false
	const W := 34.0
	const SHOWN := 14
	func _ready() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		var changed: bool = game.deck.made.size() + game.deck.burned.size() > 0
		custom_minimum_size = Vector2(0, 22 + (W * 1.4 + 24 if changed else (0.0 if compact else 40.0)))
	func _draw() -> void:
		var text := Look.colour("text")
		var tag := "THE DECK" if game.shared else "YOUR DECK"
		var tw := Look.text_width(tag, 10, "Bold", 0.8) + 12
		draw_style_box(Look.box(text, 8), Rect2(0, 3, tw, 16))
		Look.draw_text_centred(self, Vector2(tw / 2, 11), tag, 10, Look.colour("bg"), "Bold", 0.8)
		var x := tw + 6
		var base := Look.baseline_for_centre(11, 14, "SemiBold")
		x += Look.draw_text(self, Vector2(x, base), "%d cards" % int(game.deck.count), 14, text, "SemiBold") + 6
		var made: Array = game.deck.made
		var burned: Array = game.deck.burned
		if made.size() > 0:
			x += Look.draw_text(self, Vector2(x, base), "· %d made" % made.size(), 13, Look.colour("text", 0.75), "Regular") + 6
		if burned.size() > 0:
			Look.draw_text(self, Vector2(x, base), "· %d burned" % burned.size(), 13, Look.colour("text", 0.75), "Regular")
		if made.is_empty() and burned.is_empty():
			if not compact:
				var f := Look.font("Regular")
				draw_multiline_string(f, Vector2(0, 28 + f.get_ascent(13)), "A standard 52. Cards jokers make stay in it for the game, and burned cards stay out.",
					HORIZONTAL_ALIGNMENT_LEFT, size.x, 13, -1, Look.colour("text", 0.6))
			return
		var cx := 2.0
		var y := 30.0
		var shown_made := made.slice(0, SHOWN)
		var shown_burned: Array = burned.slice(0, max(0, SHOWN - shown_made.size()))
		for c in shown_made:
			_mini(Vector2(cx, y), c, new_made.has(int(c.id)), false)
			cx += W + 5
		if shown_made.size() > 0 and shown_burned.size() > 0:
			draw_rect(Rect2(cx + 3 - 5 + 2.5, y + (W * 1.4 - W * 1.2) / 2, 1, W * 1.2), Look.colour("text", 0.25))
			cx += 7
		for c in shown_burned:
			_mini(Vector2(cx, y), c, new_burned.has(int(c.id)), true)
			cx += W + 5
		var extra := made.size() + burned.size() - SHOWN
		if extra > 0:
			Look.draw_text(self, Vector2(cx, Look.baseline_for_centre(y + W * 0.7, 13)), "+%d" % extra, 13, Look.colour("text", 0.7), "SemiBold")
	func _mini(at: Vector2, c: Dictionary, fresh: bool, burned: bool) -> void:
		var r := Rect2(at, Vector2(W, W * 1.4))
		CardArt.draw(self, r, c.card, Transform2D.IDENTITY, Color(1, 1, 1, 0.45 if burned else 1.0))
		if burned:
			var red := Look.colour("card.red")
			var m := r.get_center()
			draw_line(m + Vector2(-6, -6), m + Vector2(6, 6), red, 3.5, true)
			draw_line(m + Vector2(6, -6), m + Vector2(-6, 6), red, 3.5, true)
		if c.has("percent"):
			var label := "×" + String.num(int(c.percent) / 100.0, 2)
			var w := Look.text_width(label, 9, "Bold") + 6
			var chip := Rect2(Vector2(r.get_center().x - w / 2, r.end.y - 6 + 7 - 6), Vector2(w, 12))
			draw_style_box(Look.box(Look.colour("joker.special"), 6), chip)
			Look.draw_text_centred(self, chip.get_center(), label, 9, Look.colour("bg"), "Bold")
		if fresh:
			draw_style_box(Look.box(Color.TRANSPARENT, 5, Look.colour("gold"), 2), r.grow(2))
