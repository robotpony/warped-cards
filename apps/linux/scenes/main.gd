extends Control
## The phone (ui.md › The app at a glance, Layout): the match turn screen laid out at the reference
## frame, its covers, and the window around it. Command-line options for checking against the
## reference shots in docs/images/reference/ (its README lists them): --seed N, --no-breakdown,
## --select g00,g01 (a trace in progress), --trace g00,g01 (send a trace), --arm bomb,
## --pop g02,g03 [--bomb], --breakdown g32,g33 [--stage N] (a scored set's breakdown, stopped at
## its Nth wait, or at the hold), --info hand, --end, --toast, and --shot file.png [--after ms], which
## saves the phone at 2x with 24 pt of page around it, as the reference shots are, and quits.
## scripts/reference.sh shoots the set.

var session: Session
var phone: Control
var board: Board
var header: Parts.Header
var breakdown: Breakdown
var cover_root: Control
var _cover_key := ""
var _cover: Control
var phone_h := 840.0
var margin := Look.MARGIN
var shooting := false

class Phone extends Control:
	func _draw() -> void:
		draw_style_box(Look.box(Look.colour("bg"), Look.PHONE_RADIUS), Rect2(Vector2.ZERO, size))

## The bezel, drawn over everything inside the phone so its rounded corners clip what reaches them.
class Bezel extends Control:
	func _draw() -> void:
		var r := Look.PHONE_RADIUS
		var b := Look.BEZEL
		var bezel := Look.colour("bezel")
		var ring := Look.rounded_outline(Rect2(-b / 2, -b / 2, size.x + b, size.y + b), r + b / 2, 16)
		ring.append(ring[0])
		draw_polyline(ring, bezel, b, true)
		for corner in [Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y)]:
			_corner(corner, r, bezel)
	## Fills between the phone's square corner and its rounded one.
	func _corner(c: Vector2, r: float, colour: Color) -> void:
		var sx := 1.0 if c.x == 0 else -1.0
		var sy := 1.0 if c.y == 0 else -1.0
		var centre := c + Vector2(sx * r, sy * r)
		var pts := PackedVector2Array([c])
		var start := atan2(0.0, -sx)
		var finish := atan2(-sy, 0.0)
		for i in 17:
			var a := lerp_angle(start, finish, i / 16.0)
			pts.append(centre + Vector2(cos(a), sin(a)) * (r + 0.5))
		draw_colored_polygon(pts, colour)

func _arg(name: String, fallback := "") -> String:
	var args := OS.get_cmdline_user_args()
	var i := args.find(name)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else fallback

func _flag(name: String) -> bool:
	return OS.get_cmdline_user_args().has(name)

func _ready() -> void:
	RenderingServer.set_default_clear_color(Look.colour("page"))
	if DisplayServer.get_name() != "headless":
		DisplayServer.set_icon(Image.load_from_file(Repo.path("design/icon/export/linux/crib-rpg-256.png")))
	session = Session.new()
	add_child(session)
	if session.load_error != "":
		var l := Look.label("Config didn't load: " + session.load_error, 14, Look.colour("text"))
		l.position = Vector2(20, 20)
		add_child(l)
		return
	if _flag("--no-breakdown"):
		session.settings.breakdown = false
	shooting = _arg("--shot") != ""
	if shooting:
		margin = 24.0   # the reference shots' page (docs/images/reference/README.md)
	_build()
	session.changed.connect(_covers)
	session.turn_shown.connect(_covers)
	session.new_game(int(_arg("--seed", "0")))
	_script()

func _build() -> void:
	phone = Phone.new()
	add_child(phone)
	var x := 16.0
	var w := Look.PHONE_W - 32
	var y := 14.0
	header = Parts.Header.new()
	header.session = session
	header.position = Vector2(x, y)
	header.size = Vector2(w, header.row_height() + 16)
	phone.add_child(header)
	y += header.row_height() + 10 + 6 + 10 + 9
	board = Board.new()
	board.session = session
	board.position = Vector2((Look.PHONE_W - Look.BOARD_W) / 2, y)
	phone.add_child(board)
	breakdown = Breakdown.new()
	breakdown.session = session
	breakdown.board = board
	breakdown.header = header
	breakdown.position = board.position
	phone.add_child(breakdown)
	y += Look.BOARD_H + 10
	var help := Parts.HelpLine.new()
	help.session = session
	help.position = Vector2(x, y - 4)
	help.size = Vector2(w, 20)
	phone.add_child(help)
	y += 12 + 10
	var tray := Parts.Tray.new()
	tray.session = session
	tray.position = Vector2(x, y)
	tray.size = Vector2(w, 20 + 72 * 1.4 + 14)
	phone.add_child(tray)
	y += tray.size.y + 10 + 4
	var footer := Control.new()
	footer.position = Vector2(0, y)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var counter_h := 13 + 4 + Look.font("Bold").get_height(11)
	var content_h: float = max(counter_h, 30.0)
	footer.size = Vector2(Look.PHONE_W, 12 + content_h + 20)
	footer.draw.connect(func():
		footer.draw_rect(Rect2(Vector2.ZERO, footer.size), Look.colour("panel"))
		footer.draw_rect(Rect2(0, 0, footer.size.x, 1), Look.colour("rim")))
	phone.add_child(footer)
	var counter := Parts.PickCounter.new()
	counter.session = session
	counter.position = Vector2(30, 12 + (content_h - counter_h) / 2)
	counter.size = Vector2(160, counter_h)
	footer.add_child(counter)
	var clock := Parts.Clock.new()
	clock.session = session
	clock.size = Vector2(30, 30)
	clock.position = Vector2(Look.PHONE_W - 30 - 30, 12 + (content_h - 30) / 2)
	footer.add_child(clock)
	phone_h = y + footer.size.y
	phone.size = Vector2(Look.PHONE_W, phone_h)
	cover_root = Control.new()
	cover_root.size = phone.size
	cover_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phone.add_child(cover_root)
	var toast := Parts.Toast.new()
	toast.session = session
	toast.size = phone.size
	toast.visible = not shooting or _flag("--toast")   # the reference shots hide toasts unless asked
	phone.add_child(toast)
	var bezel := Bezel.new()
	bezel.size = phone.size
	bezel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phone.add_child(bezel)
	_fit_window()

## The window is the phone plus its margin, scaled down evenly when the screen is short. A tiling
## window manager may give it another size: the phone then sits centred on the page colour
## (ui.md › Platform seams › Window).
func _fit_window() -> void:
	var base := Vector2i(int(Look.PHONE_W + 2 * margin), int(ceil(phone_h + 2 * margin)))
	var win := get_window()
	win.content_scale_size = base
	get_viewport().size_changed.connect(_centre)
	_centre()
	if DisplayServer.get_name() == "headless":
		return
	if shooting:
		win.size = base * 2
		return
	var screen := win.current_screen
	var usable := DisplayServer.screen_get_usable_rect(screen).size
	var k: float = DisplayServer.screen_get_scale(screen)
	# Godot sizes windows in pixels: the phone at the screen's scale, less if the screen is short.
	var fit: float = min(k, (usable.y - 32.0 * k) / base.y) if usable.y > 0 else k
	win.size = Vector2i(int(base.x * fit), int(base.y * fit))
	win.unresizable = true

func _centre() -> void:
	var view := get_viewport_rect().size
	size = view
	phone.position = ((view - phone.size) / 2).round()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Look.colour("page"))

func _covers() -> void:
	var key := ""
	if session.over and not session.turn.is_empty():
		key = "summary:%d" % session.game.results.size()
	elif session.info != "":
		key = "info:" + session.info
	elif session.warning != null:
		key = "warning"
	if key == _cover_key:
		return
	_cover_key = key
	if _cover:
		_cover.queue_free()
		_cover = null
	match key.get_slice(":", 0):
		"summary": _cover = Covers.summary(session)
		"info": _cover = Covers.info(session.info, session, func(): session.info = "")
		"warning": _cover = Covers.warning(session.warning, int(session.rules.match.leftOverCost), func(): session.warning = null)
	if _cover:
		cover_root.add_child(_cover)   # each cover fills its parent by its anchors

## While a breakdown plays, a tap anywhere on the phone skips it, or moves on from the hold
## (ui.md › Score breakdown › Skipping).
func _input(e: InputEvent) -> void:
	if breakdown and breakdown.active and (e is InputEventMouseButton and e.pressed or e is InputEventScreenTouch and e.pressed):
		breakdown.tap()
		get_viewport().set_input_as_handled()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.ctrl_pressed:
		if e.keycode == KEY_N:
			session.new_game()
		elif e.keycode == KEY_R:
			session.new_game(session.seed)

# MARK: Command-line checks

## Drags across positions with real mouse events, through the same input path as a person.
func _drag(ps: Array[int]) -> void:
	var at := func(p: int) -> Vector2: return board.global_position + Board.frame(p).get_center()
	var ev := func(e: InputEvent): get_viewport().push_input(e, true)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at.call(ps[0])
	ev.call(down)
	var last: Vector2 = down.position
	for p in ps:
		var to: Vector2 = at.call(p)
		for i in 4:
			var m := InputEventMouseMotion.new()
			m.button_mask = MOUSE_BUTTON_MASK_LEFT
			m.position = last.lerp(to, (i + 1) / 4.0)
			ev.call(m)
			await get_tree().process_frame
		last = to
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.position = last
	ev.call(up)

func _names(text: String) -> Array[int]:
	var out: Array[int] = []
	for n in text.split(",", false):
		out.append(Board.parse_pos(n))
	return out

func _script() -> void:
	if _arg("--arm") != "":
		session.arm(_arg("--arm"))
	if _arg("--select") != "":
		session.set_selection(_names(_arg("--select")))
	if _arg("--trace") != "":
		session.submit(_names(_arg("--trace")))
	if _arg("--drag") != "":
		await _drag(_names(_arg("--drag")))
	if _arg("--pop") != "":
		board.flash = _names(_arg("--pop"))
		board.flash_bomb = _flag("--bomb")
		session.changed.emit()
	if _arg("--info") != "":
		session.info = _arg("--info")
	if _arg("--then") != "":
		# A second move once the first has played out: "bomb:g11", "swap:g00,g01", "burn:g12", or a trace.
		while session.busy:
			await get_tree().process_frame
		var parts := _arg("--then").split(":")
		if parts.size() == 2:
			session.arm(parts[0])
			session.submit(_names(parts[1]))
		else:
			session.submit(_names(parts[0]))
	if _arg("--breakdown") != "":
		session.settings.breakdown = true
		var stage := int(_arg("--stage", "0"))
		breakdown.stop_at = stage if stage > 0 else -1
		session.submit(_names(_arg("--breakdown")))
		if shooting and _arg("--taps") == "":
			if stage > 0 and not breakdown.at_stop:
				await breakdown.stopped
			elif stage <= 0 and not breakdown.holding:
				await breakdown.held
	if _arg("--taps") != "":
		# Taps on the phone, each the given ms after the last ("400,400"): skips and moves on.
		for ms in _arg("--taps").split(","):
			await get_tree().create_timer(int(ms) / 1000.0).timeout
			var down := InputEventMouseButton.new()
			down.button_index = MOUSE_BUTTON_LEFT
			down.pressed = true
			down.position = phone.position + Vector2(Look.PHONE_W / 2, 300)
			get_viewport().push_input(down, true)
	if _flag("--end"):
		session.send({"endTurn": {}})
	if shooting:
		await get_tree().create_timer(int(_arg("--after", "800")) / 1000.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_arg("--shot"))
		get_tree().quit()
