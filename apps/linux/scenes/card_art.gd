class_name CardArt
## Cards drawn from design/cards/*.svg (ui.md › Cards; design/cards/README.md). Godot's SVG reader
## draws no text, so the text slots (rank, JOKER, the kind's word, an extra's name) are drawn here
## in Saira at each slot's centre, size and tracking, and the suit is shapes.json's shape in a
## 28 unit box centred on (25, 36).

const UNITS := 50.0
## Pixels per card unit in the cached art: crisp at 2x for the biggest card drawn (72 pt).
const RASTER := 6.0

static var _art := {}

## A card's look from its notation (engine.md › Notation): "10H", "5H*", "swapper", "amber".
static func parse(notation: String) -> Dictionary:
	var made := notation.ends_with("*")
	var t := notation.trim_suffix("*")
	var suit := t.right(1)
	var rank_text := t.left(t.length() - 1)
	if suit in ["S", "H", "D", "C"] and rank_text in ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]:
		var rank: int = {"A": 1, "J": 11, "Q": 12, "K": 13}.get(rank_text, int(rank_text) if rank_text.is_valid_int() else 0)
		return {"kind": "made" if made else "standard", "rank": rank, "rankText": rank_text, "suit": suit}
	if notation in ["amber", "teal", "title", "blank"]:
		return {"kind": "extra", "name": notation}
	return {"kind": "special", "name": notation}

static func is_playing(notation: String) -> bool:
	return parse(notation).kind in ["standard", "made"]

## Rank and suit glyph for text: "10♥", or the joker's kind.
static func face(notation: String) -> String:
	var c := parse(notation)
	if c.kind in ["standard", "made"]:
		return c.rankText + {"S": "♠", "H": "♥", "D": "♦", "C": "♣"}[c.suit]
	return notation.capitalize()

## A card's value for fifteens: its rank, with J, Q and K counting 10; 0 for jokers.
static func value(notation: String) -> int:
	var c := parse(notation)
	return min(c.rank, 10) if c.has("rank") else 0

static func _file(name: String) -> String:
	return FileAccess.get_file_as_string(Repo.path("design/cards/" + name))

static func _raster(svg: String) -> Texture2D:
	var img := Image.new()
	var err := img.load_svg_from_string(svg, RASTER)
	assert(err == OK, "card art didn't load")
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

## The card's art without its text: the frame and suit for a face, else the kind's own file.
static func art(c: Dictionary) -> Texture2D:
	var key: String = c.get("suit", "") if c.kind in ["standard", "made"] else c.kind + "-" + c.get("name", "back")
	if not _art.has(key):
		var svg: String
		if c.kind in ["standard", "made"]:
			var frame := _file("frame.svg")
			var suit := '<g transform="translate(11 22)">%s</g>' % Look.shape_svg(c.suit, Look.colour("card.suit." + c.suit), 28.0)
			svg = frame.replace("</svg>", suit + "</svg>")
		elif c.kind == "back":
			svg = _file("back.svg")
		elif c.kind == "extra":
			svg = _file("extra-%s.svg" % c.name)
		else:
			svg = _file("joker-%s.svg" % ("swap" if c.name == "swapper" else c.name))
		_art[key] = _raster(svg)
	return _art[key]

## Draws a card into `rect` (its width sets the scale). `base` is the canvas transform the caller
## draws under, since the rotated rank needs its own.
static func draw(ci: CanvasItem, rect: Rect2, notation: String, base := Transform2D.IDENTITY, modulate := Color.WHITE) -> void:
	var c := parse(notation) if notation != "back" else {"kind": "back"}
	ci.draw_texture_rect(art(c), rect, false, modulate)
	var u := rect.size.x / UNITS
	var at := func(x: float, y: float) -> Vector2: return rect.position + Vector2(x, y) * u
	match c.kind:
		"standard", "made":
			var col := Look.colour("card.suit." + c.suit) * modulate
			var ten: bool = c.rankText == "10"
			var size := (14.0 if ten else 16.0) * u
			var track := (-1.2 if ten else 0.0) * u
			Look.draw_text_centred(ci, at.call(9, 10.5), c.rankText, size, col, "Bold", track)
			var centre: Vector2 = at.call(41, 59.5)
			ci.draw_set_transform_matrix(base * Transform2D(PI, centre))
			Look.draw_text_centred(ci, Vector2.ZERO, c.rankText, size, col, "Bold", track)
			ci.draw_set_transform_matrix(base)
		"special":
			var col := Look.colour("card.joker") * modulate
			var word: String = {"swapper": "SWAP"}.get(c.name, c.name.to_upper())
			Look.draw_text_centred(ci, at.call(25, 9.5), "JOKER", 8 * u, col, "Bold", 1 * u)
			Look.draw_text_centred(ci, at.call(25, 61.5), word, 8 * u, col, "Bold", 1 * u)
		"extra":
			Look.draw_text_centred(ci, at.call(25, 35), c.name.to_upper(), 7 * u, Look.colour("card.soft") * modulate, "Bold")
