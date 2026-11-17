class_name Cell extends Node2D
## One card on the board, drawn around its centre, with the look its state gives it
## (ui.md › A card on the board): rings, halo, lift, scale, wash, glow, tags, chip and badges.

var ref := {}          ## the card reference: {id, card, percent?}
var pos := 0           ## its board position
var session: Session

## The look, as plain values (Board sets them).
var order := -1        ## place in the selection, or -1
var used := false      ## in a combo while tracing
var hit := false       ## popping before it clears
var bomb := false      ## the pop is a bomb's or a burn's (red)
var inset := false     ## in the breakdown's set
var dimmed := false    ## the breakdown is showing and this card isn't in the set
var lit := false       ## lit gold in the breakdown
var lit_power := false ## lit cyan in the breakdown
var left := false      ## left over in the breakdown
var away := false      ## flown up into the breakdown's row; the cell shows empty
var armed := false     ## the armed board joker
var chip := ""         ## the power chip's text
var chip_pulse := false

## Animated values.
var home := Vector2.ZERO:
	set(v): home = v; _place()
var lift := 0.0:
	set(v): lift = v; _place()
var grow := 1.0:
	set(v): grow = v; _place()
var vanish := 1.0:
	set(v): vanish = v; _place()
var chip_scale := 1.0
var fade := 1.0:
	set(v): fade = v; modulate.a = v

var _target := [1.0, 0.0]

func _place() -> void:
	position = home + Vector2(0, lift)
	scale = Vector2.ONE * grow * vanish

const HALF := Vector2(Look.CARD_W / 2, Look.CARD_H / 2)

func edge() -> bool:
	return pos >= 16

func starter() -> bool:
	return pos == 24

## Moves to the look's scale and lift: the pop springs, everything else eases (ui.md › Look).
func apply_look() -> void:
	var selected := order >= 0
	var g := 1.0
	if hit:
		g = 1.18 if bomb else 1.12
	elif lit or lit_power:
		g = 1.06
	elif used:
		g = 1.1
	elif selected:
		g = 1.04
	var l := 0.0
	if lit or lit_power:
		l = -8.0
	elif inset or used:
		l = -4.0
	elif selected:
		l = -2.0
	elif armed:
		l = -6.0
	if _target != [g, l]:
		var s := Motion.spec("board.pop" if hit or _target[0] in [1.12, 1.18] else ("breakdown.light" if lit or lit_power else "board.select"))
		Motion.animate(self, "grow", g, s, true, self)
		Motion.animate(self, "lift", l, s, true, self)
		_target = [g, l]
	var cs := 1.5 if chip_pulse else 1.0
	if chip_scale != cs:
		Motion.animate(self, "chip_scale", cs, Motion.spec("breakdown.powerUp"), true, self)
	z_index = 1 if selected or hit or lit or lit_power else 0
	visible = not away
	queue_redraw()

func _draw() -> void:
	var selected := order >= 0
	var rect := Rect2(-HALF, HALF * 2)
	var r := Look.CARD_RADIUS
	var rot := deg_to_rad(-5.0) if starter() else 0.0
	var turn_ := Transform2D(rot, Vector2.ZERO)
	draw_set_transform_matrix(turn_)
	# Steady looks without blur: a soft gold halo on edge cards, a hard drop shadow when raised.
	if edge() and not selected and not hit:
		draw_style_box(Look.box(Color.TRANSPARENT, r + 4, Look.colour("gold", 0.22), 4), rect.grow(4))
	if selected or starter():
		draw_style_box(Look.box(Color(0, 0, 0, 0.35), r), Rect2(rect.position + Vector2(0, 4), rect.size))
	# One soft glow, only while a card is lit, popped or in a combo.
	var glow = null
	if hit:
		glow = Look.colour("card.red", 0.85) if bomb else Look.colour("gold", 0.9)
	elif lit:
		glow = Look.colour("gold", 0.85)
	elif lit_power:
		glow = Look.colour("cyan", 0.8)
	elif left:
		glow = Look.colour("leftOver.ring", 0.7)
	elif used:
		glow = Color(1, 1, 1, 0.55)
	if glow != null:
		draw_style_box(Look.box(Color(glow, 0.0), r, Color.TRANSPARENT, 0, glow, 10 if hit else 9), rect)
	CardArt.draw(self, rect, ref.card, turn_)
	if dimmed:
		draw_style_box(Look.box(Look.colour("bg", 0.72), r), rect)
	elif used:
		draw_style_box(Look.box(Color(1, 1, 1, 0.08), r), rect)
	# Rings sit outside the card.
	var w := 3.0 if used or armed else 2.0
	var ring = null
	if selected or armed:
		ring = Color.WHITE
	elif starter():
		ring = Look.colour("text")
	elif edge():
		ring = Look.colour("gold")
	if ring != null:
		_ring(rect, r, w, ring)
	var ring2 = null
	if hit or (inset and not lit and not lit_power and not left):
		ring2 = Color.WHITE
	elif lit:
		ring2 = Look.colour("gold")
	elif lit_power:
		ring2 = Look.colour("cyan")
	elif left:
		ring2 = Look.colour("leftOver.ring")
	if ring2 != null:
		_ring(rect, r, 3.0, ring2)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	# Tags, the chip and badges ride with the card's lift and scale, not its tilt.
	var tag := "STARTER" if starter() else ("HAND" if pos == 16 else ("CRIB" if pos == 20 else ""))
	if tag != "":
		var fill := Look.colour("text") if starter() else Look.colour("gold")
		var ink := Look.colour("bg") if starter() else Look.colour("ink")
		var tw := Look.text_width(tag, 10, "Bold", 0.8) + 12
		var centre := Vector2(-10.0 if chip != "" else 0.0, -HALF.y - 10 + 8)
		_capsule(Rect2(centre - Vector2(tw / 2, 8), Vector2(tw, 16)), fill, tag, 10, ink, 0.8)
	if chip != "":
		var cw: float = max(18.0, Look.text_width(chip, 12, "Bold") + 12)
		var at := Vector2(HALF.x + 6 - cw / 2, -HALF.y - 6 + 9)
		draw_set_transform(at, 0, Vector2.ONE * chip_scale)
		_capsule(Rect2(Vector2(-cw / 2, -9), Vector2(cw, 18)), Look.colour("cyan") if chip_pulse else Look.colour("gold"), chip, 12, Look.colour("ink"))
		draw_set_transform_matrix(Transform2D.IDENTITY)
	if ref.card.ends_with("*"):
		_badge(Vector2(-HALF.x - 5 + 8, -HALF.y - 5 + 8), "★", Look.colour("gold"), Look.colour("ink"), 16)
	if selected:
		_badge(Vector2(-HALF.x - 4 + 9, HALF.y + 4 - 9), str(order + 1), Color.WHITE, Look.colour("bg"), 18)

func _ring(rect: Rect2, r: float, w: float, c: Color) -> void:
	var s := Look.box(Color.TRANSPARENT, r + w / 2, c, w)
	draw_style_box(s, rect.grow(w))

func _capsule(rect: Rect2, fill: Color, text: String, size: float, ink: Color, tracking := 0.0) -> void:
	draw_style_box(Look.box(fill, rect.size.y / 2), rect)
	Look.draw_text_centred(self, rect.get_center(), text, size, ink, "Bold", tracking)

func _badge(centre: Vector2, text: String, fill: Color, ink: Color, size: float) -> void:
	draw_circle(centre, size / 2, fill, true, -1, true)
	Look.draw_text_centred(self, centre, text, size * 0.62, ink, "Bold")
