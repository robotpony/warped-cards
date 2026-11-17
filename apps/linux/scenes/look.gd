class_name Look
## Colours, type and sizes, read from the shared files where they live (ui.md › Look):
## colours from design/neon/palette.json, the face from design/fonts/, suits and ★ from
## design/neon/shapes.json. Nothing is copied: a colour the file lacks is an error, not a guess.

# Sizes at the reference frame, a 64 pt card (ui.md › Layout). Layout sizes stay in code (Hard-coded
# numbers leaves them to a layout file, not game config).
const CARD_W := 64.0
const CARD_H := CARD_W * 1.4
const GAP := 5.0
const EDGE_GAP := 12.0
const CARD_RADIUS := 5.0
const EDGE_PAD := 6.0
const EDGE_PAD_OUTER := 9.0
const PITCH_X := CARD_W + GAP
const PITCH_Y := CARD_H + GAP
const BOARD_W := 4 * PITCH_X + EDGE_GAP + CARD_W
const BOARD_H := 4 * PITCH_Y + EDGE_GAP + CARD_H
const PHONE_W := BOARD_W + 2 * 16 + 18
const PHONE_RADIUS := 42.0
const BEZEL := 10.0
const MARGIN := 20.0

static var _colours := {}
static var _fonts := {}
static var _shapes := {}
static var _marks := {}

## A colour by its path in palette.json › colours ("cyan", "joker.special", "card.suit.H").
static func colour(path: String, alpha := 1.0) -> Color:
	if _colours.is_empty():
		_walk(Repo.read_json("design/neon/palette.json").colours, "")
	assert(_colours.has(path), "palette.json has no colour " + path)
	var c: Color = _colours.get(path, Color.MAGENTA)
	c.a = alpha
	return c

static func _walk(node: Variant, path: String) -> void:
	if node is String:
		_colours[path] = Color.html(node)
	elif node is Dictionary:
		for k in node:
			_walk(node[k], k if path == "" else path + "." + k)
	elif node is Array:
		for i in node.size():
			_walk(node[i], path + "." + str(i))

## Saira Semi Condensed by weight: "Regular", "Medium", "SemiBold" or "Bold".
static func font(weight := "SemiBold") -> Font:
	if not _fonts.has(weight):
		var f := FontFile.new()
		var err := f.load_dynamic_font(Repo.path("design/fonts/saira-semi-condensed/SairaSemiCondensed-%s.ttf" % weight))
		assert(err == OK, "Saira %s didn't load" % weight)
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		_fonts[weight] = f
	return _fonts[weight]

## A shapes.json shape ("S", "H", "D", "C", "star") as SVG path data in its 20 × 20 box.
static func shape_svg(name: String, fill: Color, box := 20.0) -> String:
	if _shapes.is_empty():
		_shapes = Repo.read_json("design/neon/shapes.json").shapes
	var out := ""
	for part in _shapes[name]:
		var paint: String = 'fill="#%s"' % fill.to_html(false) if part.mode == "fill" else 'fill="none" stroke="#%s" stroke-width="%s"' % [fill.to_html(false), part.get("w", 1)]
		out += '<path d="%s" %s/>' % [part.d, paint]
	if box == 20.0:
		return out
	return '<g transform="scale(%s)">%s</g>' % [box / 20.0, out]

## A suit or ★ as a white texture (tint it when drawing), for marks inside text.
static func mark(name: String) -> Texture2D:
	if not _marks.has(name):
		var img := Image.new()
		img.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" width="20" height="20">%s</svg>' % shape_svg(name, Color.WHITE), 6.0)
		img.generate_mipmaps()
		_marks[name] = ImageTexture.create_from_image(img)
	return _marks[name]

const MARK_CHARS := {"♠": "S", "♥": "H", "♦": "D", "♣": "C", "★": "star"}

## Draws one line of text at a baseline point, with letter-spacing, and suits and ★ as shapes
## 0.8 em square sitting 0.06 em below the baseline (ui.md › Type). Answers the width drawn.
static func draw_text(ci: CanvasItem, pos: Vector2, text: String, size: float, colour_: Color, weight := "SemiBold", tracking := 0.0) -> float:
	var f := font(weight)
	var x := pos.x
	for ch in text:
		if MARK_CHARS.has(ch):
			var s := size * 0.8
			ci.draw_texture_rect(mark(MARK_CHARS[ch]), Rect2(x, pos.y + size * 0.06 - s, s, s), false, colour_)
			x += s + size * 0.06 + tracking
		else:
			ci.draw_string(f, Vector2(x, pos.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(size)), colour_)
			x += f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(size))).x + tracking
	return x - pos.x - tracking

static func text_width(text: String, size: float, weight := "SemiBold", tracking := 0.0) -> float:
	var f := font(weight)
	var w := 0.0
	for ch in text:
		w += (size * 0.86 if MARK_CHARS.has(ch) else f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(size))).x) + tracking
	return w - tracking if text != "" else 0.0

## The baseline that centres a line of text of this size on y.
static func baseline_for_centre(y: float, size: float, weight := "SemiBold") -> float:
	var f := font(weight)
	var s := int(round(size))
	return y + (f.get_ascent(s) - f.get_descent(s)) / 2.0

## Draws text centred on a point.
static func draw_text_centred(ci: CanvasItem, centre: Vector2, text: String, size: float, colour_: Color, weight := "SemiBold", tracking := 0.0) -> void:
	var w := text_width(text, size, weight, tracking)
	draw_text(ci, Vector2(centre.x - w / 2.0, baseline_for_centre(centre.y, size, weight)), text, size, colour_, weight, tracking)

## Text into a RichTextLabel, with suits and ★ as inline shapes in the text's colour.
static func rich(label: RichTextLabel, text: String, size: float, colour_: Color, weight := "SemiBold") -> void:
	label.clear()
	label.push_font(font(weight), int(round(size)))
	label.push_color(colour_)
	var run := ""
	for ch in text:
		if MARK_CHARS.has(ch):
			label.add_text(run)
			run = ""
			var s := int(round(size * 0.8))
			label.add_image(mark(MARK_CHARS[ch]), s, s, colour_, INLINE_ALIGNMENT_BOTTOM_TO | INLINE_ALIGNMENT_TO_BASELINE)
		else:
			run += ch
	label.add_text(run)
	label.pop_all()

## A plain Label in Saira.
static func label(text: String, size: float, colour_: Color, weight := "SemiBold") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", int(round(size)))
	l.add_theme_color_override("font_color", colour_)
	return l

## A rounded box style: fill, border and a soft shadow, all optional.
static func box(fill: Color, radius: float, border := Color.TRANSPARENT, border_w := 0.0, shadow := Color.TRANSPARENT, shadow_size := 0.0, shadow_offset := Vector2.ZERO) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.draw_center = fill.a > 0.0
	s.set_corner_radius_all(int(round(radius)))
	s.corner_detail = 12
	s.anti_aliasing = true
	if border_w > 0.0:
		s.border_color = border
		s.set_border_width_all(int(ceil(border_w)))
	s.shadow_color = shadow
	s.shadow_size = int(round(shadow_size))
	s.shadow_offset = shadow_offset
	return s

## Points around a rounded rectangle, clockwise from just after the top-left corner, as SVG
## strokes a rect (ui.md › Cards), so dashes start in the same place in every build.
static func rounded_outline(r: Rect2, radius: float, per_corner := 8) -> PackedVector2Array:
	var pts := PackedVector2Array()
	radius = min(radius, min(r.size.x, r.size.y) / 2.0)
	var corners := [
		[Vector2(r.end.x - radius, r.position.y + radius), -PI / 2],
		[Vector2(r.end.x - radius, r.end.y - radius), 0.0],
		[Vector2(r.position.x + radius, r.end.y - radius), PI / 2],
		[Vector2(r.position.x + radius, r.position.y + radius), PI],
	]
	pts.append(Vector2(r.position.x + radius, r.position.y))
	for c in corners:
		for i in per_corner + 1:
			var a: float = c[1] + (PI / 2) * i / per_corner
			pts.append(c[0] + Vector2(cos(a), sin(a)) * radius)
	return pts

## A dashed outline along a closed polyline.
static func draw_dashed(ci: CanvasItem, pts: PackedVector2Array, colour_: Color, width: float, dash: float, gap: float) -> void:
	var on := true
	var left := dash
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var seg := a.distance_to(b)
		var t := 0.0
		while t < seg:
			var step: float = min(left, seg - t)
			if on:
				ci.draw_line(a.lerp(b, t / seg), a.lerp(b, (t + step) / seg), colour_, width, true)
			t += step
			left -= step
			if left <= 0.0001:
				on = not on
				left = dash if on else gap
