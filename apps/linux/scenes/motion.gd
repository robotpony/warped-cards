class_name Motion
## Every cue's motion and wait, from cribbage/minigames/config/fx.json (ui.md › Motion). Nothing
## here is a number of its own: springs are stepped from their duration and bounce, curves from
## the Bézier table, and every duration goes through one scale (slow motion).

static var scale := 1.0
static var _fx := {}
static var _settle := {}

static func fx() -> Dictionary:
	if _fx.is_empty():
		_fx = Repo.read_json("cribbage/minigames/config/fx.json")
		assert(_fx.has("motions") and _fx.has("waits"), "config/fx.json didn't load")
	return _fx

## A motion by its path under motions: "board.pop", "breakdown.rowFly".
static func spec(path: String) -> Dictionary:
	var node: Variant = fx().motions
	for k in path.split("."):
		node = node[k]
	return node

## A wait by its path under waits, in ms: "board.settle", "toast".
static func wait(path: String) -> Variant:
	var node: Variant = fx().waits
	for k in path.split("."):
		node = node[k]
	return node

## A wait in seconds, through the slow-motion scale.
static func secs(ms: float, scaled := true) -> float:
	return ms / 1000.0 * (scale if scaled else 1.0)

## How long a motion runs, in seconds: a curve's ms, or a spring's time to settle.
static func duration(s: Dictionary, scaled := true) -> float:
	var d: float = s.ms / 1000.0
	if s.type == "spring":
		d = _settle_time(s)
	return d * (scale if scaled else 1.0)

## The motion's progress at t seconds (unscaled time), 0 to 1, overshooting for a bouncy spring.
static func at(s: Dictionary, t: float) -> float:
	var d: float = s.ms / 1000.0
	match s.type:
		"spring":
			return _spring(d, s.get("bounce", 0.0), t)
		"linear":
			return clamp(t / d, 0.0, 1.0)
		"easeIn":
			return _bezier(0.42, 0.0, 1.0, 1.0, t / d)
		"easeInOut":
			return _bezier(0.42, 0.0, 0.58, 1.0, t / d)
		_:
			return _bezier(0.0, 0.0, 0.58, 1.0, t / d)

## A damped spring with mass 1, stiffness (2π/d)² and damping 4π(1 − b)/d, from 0 to 1
## (ui.md › Motion › Springs). Solved in closed form: the same stiffness and damping.
static func _spring(d: float, b: float, t: float) -> float:
	if t <= 0.0:
		return 0.0
	var w0 := TAU / d
	var z := 1.0 - b
	if z >= 1.0:
		return 1.0 - exp(-w0 * t) * (1.0 + w0 * t)
	var wd := w0 * sqrt(1.0 - z * z)
	return 1.0 - exp(-z * w0 * t) * (cos(wd * t) + z * w0 / wd * sin(wd * t))

## When a spring has settled: within 0.001 of 1 and slower than 0.01 a second.
static func _settle_time(s: Dictionary) -> float:
	var key := "%s/%s" % [s.ms, s.get("bounce", 0.0)]
	if not _settle.has(key):
		var d: float = s.ms / 1000.0
		var b: float = s.get("bounce", 0.0)
		var t := 0.0
		var dt := 0.001
		var x := 0.0
		while t < 10.0:
			t += dt
			var nx := _spring(d, b, t)
			if abs(1.0 - nx) < 0.001 and abs(nx - x) / dt < 0.01:
				break
			x = nx
		_settle[key] = t
	return _settle[key]

## A cubic Bézier ease from (0,0) to (1,1) through (x1,y1) and (x2,y2), at x.
static func _bezier(x1: float, y1: float, x2: float, y2: float, x: float) -> float:
	x = clamp(x, 0.0, 1.0)
	var u := x
	for i in 8:
		var cx := 3.0 * x1 * u * (1.0 - u) * (1.0 - u) + 3.0 * x2 * u * u * (1.0 - u) + u * u * u - x
		var dx := 3.0 * x1 * (1.0 - u) * (1.0 - u) + 6.0 * (x2 - x1) * u * (1.0 - u) + 3.0 * (1.0 - x2) * u * u
		if abs(dx) < 1e-6:
			break
		u = clamp(u - cx / dx, 0.0, 1.0)
	return 3.0 * y1 * u * (1.0 - u) * (1.0 - u) + 3.0 * y2 * u * u * (1.0 - u) + u * u * u

## Moves a property of `obj` to `to` with a motion. Kills the property's last move first, so a new
## change starts from where the old one had got to, as a retargeted animation does.
## `redraw` is queued on every frame (a CanvasItem that draws the value itself).
static func animate(obj: Object, prop: String, to: Variant, s: Dictionary, scaled := true, redraw: CanvasItem = null) -> Tween:
	var key := "_motion_" + prop
	if obj.has_meta(key):
		var old: Tween = obj.get_meta(key)
		if old and old.is_valid():
			old.kill()
	var from: Variant = obj.get(prop)
	var host: Node = obj if obj is Node else redraw
	var tw := host.create_tween()
	var length := duration(s, scaled)
	var k := (scale if scaled else 1.0)
	if s.get("repeat", false):
		tw.set_loops()
		tw.tween_method(func(t: float): _apply(obj, prop, from, to, at(s, t / k), redraw), 0.0, length, length)
		tw.tween_method(func(t: float): _apply(obj, prop, from, to, 1.0 - at(s, t / k), redraw), 0.0, length, length)
	else:
		tw.tween_method(func(t: float): _apply(obj, prop, from, to, at(s, t / k) if t < length else 1.0, redraw), 0.0, length, length)
	obj.set_meta(key, tw)
	return tw

static func _apply(obj: Object, prop: String, from: Variant, to: Variant, p: float, redraw: CanvasItem) -> void:
	if not is_instance_valid(obj):
		return
	if from is Color:
		obj.set(prop, (from as Color).lerp(to, p))
	else:
		obj.set(prop, from + (to - from) * p)
	if redraw:
		redraw.queue_redraw()

## Sets a property at once, stopping any move on it.
static func snap(obj: Object, prop: String, to: Variant) -> void:
	var key := "_motion_" + prop
	if obj.has_meta(key):
		var old: Tween = obj.get_meta(key)
		if old and old.is_valid():
			old.kill()
	obj.set(prop, to)
