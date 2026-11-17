class_name Session extends Node
## The game controller (ui.md › Terms, Session): owns the clock and timers, sends actions to the
## engine and keeps what the screen shows. The engine decides everything. What's shown (`turn`)
## lags behind the engine while a move's cues play (ARCHITECTURE.md › How a move flows).

signal changed                       ## anything shown changed: redraw
signal board_moved(drawn_per_column) ## a move's board change, to animate
signal pop(positions, bomb)          ## cards pop before they clear
signal breakdown(score, before)      ## a score's breakdown starts (Score breakdown)
signal toast_changed
signal turn_shown                    ## a new turn is on screen

var engine: Object
var rules := {}
var timing := {}
var load_error := ""

## Settings live for the session only (ui.md › Settings panel).
var settings := {
	"dealer": true, "timer": true, "hand": "random", "budget": 0,
	"breakdown": false, "hints": true, "deal": false, "sharedDeck": true,   # breakdown and deal: on once their scenes are built
}
var breakdown_base := 1200.0

var seed := 1
var game := {}           ## gameState(): the game around the turn
var turn := {}           ## turnState() as presented
var events := []         ## this turn's events so far
var feed := []           ## the turn's log, newest first
var last_score := {}

var mode := "trace"      ## trace, swap, bomb, burn
var selection: Array[int] = []
var armed_source := -1   ## a board joker's position, or -1 for the tray
var busy := false:
	set(v): busy = v; _sync_clock(); changed.emit()
var warning = null:      ## the cards left over, while the left-over warning shows
	set(v): warning = v; _sync_clock(); changed.emit()
var info := "":          ## the info card showing: hand, crib, starter, tray, counter
	set(v): info = v; _sync_clock(); changed.emit()
var toast := ""
var seconds_left := 0
var grace_left := -1     ## seconds of the stuck grace, or -1
var reach_left := {}     ## reach id → [left, total]
var bump := false        ## the steps number after a breakdown

const GRACE_SECONDS := 25   # ui.md › Hard-coded numbers 1: not in config yet

var _clock_base := 0.0
var _clock_since := -1.0
var _toast_id := 0
var _timer: Timer
var _reach_timer: Timer
var _dead_id := 0

func _ready() -> void:
	engine = ClassDB.instantiate("CribEngine")
	if engine == null:
		load_error = "The engine bridge didn't load"
		return
	load_error = engine.loadConfig(Repo.path("cribbage/minigames/config"))
	rules = Repo.read_json("cribbage/minigames/config/rules.json")
	timing = Repo.read_json("cribbage/minigames/config/timing.json").profiles.human
	breakdown_base = timing.breakdownBase
	Motion.fx()
	_timer = _ticker(_tick_turn)
	_reach_timer = _ticker(_tick_reaches)
	_clock_since = _now()

func _ticker(f: Callable) -> Timer:
	var t := Timer.new()
	t.wait_time = 1.0
	t.timeout.connect(f)
	add_child(t)
	return t

# MARK: Game time (engine.md › Clock and timer): stops whenever the turn timer pauses.

func _now() -> float:
	return Time.get_ticks_usec() / 1000.0

var paused: bool:
	get: return busy or warning != null or info != ""

func _sync_clock() -> void:
	if paused and _clock_since >= 0.0:
		_clock_base += _now() - _clock_since
		_clock_since = -1.0
	elif not paused and _clock_since < 0.0:
		_clock_since = _now()

func game_ms() -> int:
	return int(_clock_base + (_now() - _clock_since if _clock_since >= 0.0 else 0.0))

# MARK: State the screen reads

var blocked: bool:
	get: return over or busy or warning != null or info != ""
var over: bool:
	get: return turn.is_empty() or turn.over
var dead: bool:
	get: return not turn.is_empty() and turn.dead
var more_turns: bool:
	get: return not game.get("over", true)

func cell(p: int) -> Variant:
	return turn.cells[p] if not turn.is_empty() else null

func pick_limit() -> int:
	return turn.get("pickLimit", rules.match.maxSet)

func picked_count() -> int:
	if turn.is_empty():
		return 0
	return selection.filter(func(p): return not (p == 24 and turn.starterJoins)).size()

func preview(ps: Array) -> Dictionary:
	return JSON.parse_string(engine.preview(JSON.stringify(ps)))

# MARK: Starting games and turns

func new_game(fixed_seed := 0) -> void:
	if load_error != "":
		return
	seed = fixed_seed if fixed_seed > 0 else randi_range(1, 999_999)   # app only: the engine never draws its own randomness
	_clock_base = 0.0
	_clock_since = -1.0 if paused else _now()
	var opening = JSON.parse_string(engine.newGameWith(seed, "classic", settings.dealer, settings.sharedDeck))
	if opening.has("error"):
		_show(opening.error)
		return
	_start_turn()

func next_turn() -> void:
	if more_turns and over:
		_start_turn()

func _start_turn() -> void:
	var strong: bool = settings.hand == "strong"
	var options := {"deal": settings.deal and not strong, "warned": false}
	if strong:
		options.fixedHand = ["4H", "5C", "6D", "JS"]   # ui.md › Hard-coded numbers 33
		options.fixedStarter = "5S"
	if settings.budget > 0:
		options.cardBudget = settings.budget
	if not settings.timer:
		options.timerSeconds = 0
	var step = _act({"startHand": {"options": options}})
	if step == null:
		return
	game = JSON.parse_string(engine.gameState())
	if game.stage == "dealing":
		# The deal scene isn't built yet: throw the first 2 of the 6 (apps/linux/README.md › Status).
		var d: Dictionary = game.dealing
		step = _act({"discard": {"thrown": [d.player[0], d.player[1]]}})
		if step == null:
			return
	_begin(step)

func _begin(step: Dictionary) -> void:
	_dead_id += 1
	grace_left = -1
	reach_left = {}
	_reach_timer.stop()
	game = JSON.parse_string(engine.gameState())
	turn = JSON.parse_string(engine.turnState())
	events = []
	feed = []
	last_score = {}
	mode = "trace"
	selection = []
	armed_source = -1
	warning = null
	info = ""
	toast = ""
	for e in step.events:
		events.append(e)
		_describe(e)
	seconds_left = turn.get("timerSeconds", 0)
	_timer.stop()
	if seconds_left > 0:
		_timer.start()
	turn_shown.emit()
	changed.emit()
	if turn.over:
		_finish()
	else:
		_watch_dead_board()

## Sends an action, stamped with game time. Answers the step, or null (and a toast) if refused.
func _act(action: Dictionary, player := 0) -> Variant:
	var r = JSON.parse_string(engine.send(JSON.stringify(action), player, game_ms()))
	if r == null or r.has("error"):
		_show(str(r.error) if r else "The engine didn't answer")
		return null
	return r

# MARK: Moves

func send(action: Dictionary) -> void:
	if busy or over:
		return
	var old := turn
	var player := -1 if action.keys()[0] in ["timeUp", "reachOver", "endTurn"] else 0
	var step = _act(action, player)
	if step == null:
		return
	var t = JSON.parse_string(engine.turnState())
	var ev: Array = step.events.filter(func(e): return not (e.keys()[0] in ["handStart", "deal", "discard", "handEnd", "gameEnd", "gameStart"]))
	events.append_array(ev)
	# What pops first: the scored set, or the cards a bomb or burn hits.
	var hit: Array[int] = []
	var bomb := false
	var score = null
	for e in step.events:
		var k: String = e.keys()[0]
		if k == "score":
			score = e.score
			hit.assign(e.score.positions.map(Board.parse_pos))
		elif k == "bomb":
			bomb = true
			var ids := {}
			for c in e.bomb.cleared:
				ids[int(c.id)] = true
			hit.assign(range(25).filter(func(p): return old.cells[p] != null and ids.has(int(old.cells[p].id))))
		elif k == "burn":
			bomb = true
			hit.assign([Board.parse_pos(e.burn.target)])
	if hit.is_empty():
		_commit(t, ev)
		return
	if not bomb and settings.breakdown and score != null:
		busy = true
		selection = []
		breakdown.emit(score, old)
		await breakdown_done
		_commit(t, ev)
		bump = true
		changed.emit()
		await get_tree().create_timer(Motion.secs(Motion.wait("board.settle"))).timeout
		bump = false
		busy = false
		return
	busy = true
	pop.emit(hit, bomb)
	await get_tree().create_timer(Motion.secs(Motion.wait("board.bombPop" if bomb else "board.pop"))).timeout
	pop.emit([] as Array[int], bomb)
	_commit(t, ev)
	await get_tree().create_timer(Motion.secs(Motion.wait("board.settle"))).timeout
	busy = false

## The breakdown scene says when it has played out (Score breakdown › Cue sheet, order 15).
signal breakdown_done

## Shows the move's result: cards clear, fall and drop in.
func _commit(t: Dictionary, ev: Array) -> void:
	var drawn := [0, 0, 0, 0]
	for e in ev:
		if e.has("boardChanged"):
			for d in e.boardChanged.drawn:
				var p := Board.parse_pos(d.cell)
				if p < 16:
					drawn[p % 4] += 1
	turn = t
	game = JSON.parse_string(engine.gameState())
	board_moved.emit(drawn)
	for e in ev:
		_describe(e)
	_watch_reaches()
	if turn.over:
		_finish()
	else:
		_watch_dead_board()
	changed.emit()

func submit(ps: Array[int]) -> void:
	match mode:
		"trace":
			send({"trace": {"positions": ps}})
		"swap":
			if engine.isLine(JSON.stringify(ps)):
				mode = "trace"
				send({"swap": _with_source({"line": ps})})
			else:
				_show("Trace a straight line of 2 to 4 grid cards")
				return
		"bomb":
			if ps.size() > 0 and ps[0] < 16:
				mode = "trace"
				send({"bomb": _with_source({"target": ps[0]})})
		"burn":
			if ps.size() > 0 and ps[0] < 16 and cell(ps[0]) != null and CardArt.is_playing(cell(ps[0]).card):
				mode = "trace"
				send({"burn": _with_source({"target": ps[0]})})
			else:
				_show("Tap a playing card on the grid to burn it")
				return
	armed_source = -1
	changed.emit()

func _with_source(fields: Dictionary) -> Dictionary:
	if armed_source >= 0:
		fields.source = armed_source
	return fields

const ARMS := {"swapper": "swap", "bomb": "bomb", "burn": "burn"}

## Arms a power joker; a reach needs no target, so it's used at once.
func arm(kind: String, source := -1) -> void:
	if kind == "reach":
		selection = []
		send({"reach": {"source": source}} if source >= 0 else {"reach": {}})
		return
	if not ARMS.has(kind):
		return
	if kind == "burn" and not turn.canBurn:
		_show("The deck is as small as it gets: %d cards" % turn.deckSize)
		return
	armed_source = source
	mode = ARMS[kind]
	_show({"swapper": "Trace a straight line to reverse it", "bomb": "Tap a grid card to blast it",
		"burn": "Tap a grid card to burn it out of the deck"}[kind])
	changed.emit()

func disarm() -> void:
	mode = "trace"
	armed_source = -1
	selection = []
	changed.emit()

func tap_tray(kind: String) -> void:
	if over or int(turn.tray.get(kind, 0)) < 1:
		return
	if kind == "reach":
		if mode == "trace":
			arm(kind)
		return
	if mode == ARMS[kind] and armed_source < 0:
		disarm()
	else:
		selection = []
		arm(kind)

func set_selection(sel: Array[int]) -> void:
	if sel != selection:
		selection = sel
		changed.emit()

## Selected cards in a combo light up; with a swapper armed, the whole line does.
func lit_positions() -> Array:
	if mode == "swap":
		return selection
	if mode != "trace" or selection.size() < 2 or turn.is_empty():
		return []
	for p in selection:
		if cell(p) == null or not CardArt.is_playing(cell(p).card):
			return []
	var v = preview(selection).get("value")
	if v == null:
		return []
	var lit := {}
	for c in v.combos:
		for i in c.cards:
			lit[int(v.counted[int(i)])] = true
	return lit.keys()

## The edge power multiplier for a level: ×1.1, ×1.2, up to the cap.
func multiplier_text(level: int) -> String:
	var ep: Dictionary = rules.match.edgePower
	var pct: int = 100 + int(ep.percentPerLevel) * level
	if ep.capPercent > 0:
		pct = min(pct, int(ep.capPercent))
	return multiplier_percent(pct)

static func multiplier_percent(pct: int) -> String:
	if pct % 100 == 0:
		return "×%d" % (pct / 100)
	return "×" + String.num(pct / 100.0, 2).trim_suffix("0") if pct % 10 == 0 else "×" + String.num(pct / 100.0, 2)

# MARK: The help line (ui.md › The help line)

func help_line() -> String:
	if mode == "bomb":
		return "Bomb armed: tap a grid card to blow it up. Tap the bomb again to cancel."
	if mode == "burn":
		return "Burn armed: tap a grid card to take it out of the deck for the game. Tap the burn again to cancel."
	if mode == "swap" and selection.is_empty():
		return "Swapper armed: trace a straight line of 2 to 4 grid cards to reverse it. Tap the swapper again to cancel."
	if turn.is_empty():
		return ""
	if selection.is_empty():
		if turn.dead:
			return "No sets left. Use a power joker before the clock fills." if grace_left >= 0 else "No sets left on the board. The turn is over."
		return ""
	var cards := selection.filter(func(p): return cell(p) != null).map(func(p): return cell(p).card)
	var sum := 0
	for c in cards:
		sum += CardArt.value(c)
	var msg := " ".join(cards.map(CardArt.face)) + "  (sum %d)" % sum
	if mode == "swap":
		return msg + (": reverse this line" if engine.isLine(JSON.stringify(selection)) else ": not a straight line")
	if selection.size() < 2:
		return msg
	var pv := preview(selection)
	if pv.get("problem") != null:
		var why = {"no_grid_card": "needs a grid card", "already_scored": "already scored", "not_touching": "cards must touch", "special": "a special joker can't score"}.get(pv.problem)
		return msg + ": " + why if why != null else msg
	var v = pv.get("value")
	if v == null:
		return msg
	var names := " + ".join(v.combos.map(combo_name))
	var left := " ".join(v.leftOverPositions.map(func(p): return CardArt.face(cell(int(p)).card)))
	var cost: int = int(rules.match.leftOverCost) * int(v.leftOver)
	if v.combos.is_empty():
		msg += ": no combo" + (" (−%d)" % cost if turn.warned else "")
	elif v.leftOver == 0:
		msg += ": %s (+%d)" % [names, v.points]
	elif turn.warned:
		msg += ": %s (+%d), %s left over (−%d) = %s%d" % [names, v.multiplied, left, cost, "+" if v.points >= 0 else "", v.points]
	else:
		msg += ": %s left over" % left
	return msg

static func combo_name(c: Dictionary) -> String:
	match c.kind:
		"fifteen": return "fifteen"
		"pair": return {3: "pair royal", 4: "double pair royal"}.get(int(c.get("size", 2)), "pair")
		"run": return "run of %d" % int(c.get("size", 3)) + (" ×%d" % int(c.multiplier) if int(c.get("multiplier", 1)) > 1 else "")
		"flush": return "flush of %d" % int(c.get("size", 4))
		"nobs": return "his nobs"
	return c.kind

# MARK: Timers (ui.md › Timers). Each ticks once a second; a tick while paused is skipped.

func _tick_turn() -> void:
	if over:
		_timer.stop()
		return
	if paused:
		return
	seconds_left -= 1
	changed.emit()
	if seconds_left <= 0:
		_timer.stop()
		send({"timeUp": {}})

func _watch_reaches() -> void:
	var live := {}
	for r in turn.reaches:
		live[int(r.id)] = true
		if not reach_left.has(int(r.id)):
			reach_left[int(r.id)] = [int(r.seconds), int(r.seconds)]
	for id in reach_left.keys():
		if not live.has(id):
			reach_left.erase(id)
	if not reach_left.is_empty() and _reach_timer.is_stopped():
		_reach_timer.start()

func _tick_reaches() -> void:
	if over or reach_left.is_empty():
		_reach_timer.stop()
		return
	if paused:
		return
	for id in reach_left:
		reach_left[id][0] -= 1
	for id in reach_left.keys():
		if reach_left[id][0] <= 0:
			reach_left.erase(id)
			send({"reachOver": {"id": id}})
			break   # at most one reach ends per tick
	if reach_left.is_empty():
		_reach_timer.stop()
	changed.emit()

## The share of time left on the reach that ends first, or -1 with none in effect.
func reach_fraction() -> float:
	var best := -1.0
	var least := 1 << 30
	for id in reach_left:
		var r: Array = reach_left[id]
		if r[0] < least:
			least = r[0]
			best = max(0, r[0]) / float(max(1, r[1]))
	return best

## No End turn button: a board with no sets left ends the turn by itself. With no power jokers
## it ends after a beat; with some, the player gets a grace to use one.
func _watch_dead_board() -> void:
	_dead_id += 1
	var id := _dead_id
	grace_left = -1
	if not dead or over:
		return
	var has_jokers := false
	for k in turn.tray:
		has_jokers = has_jokers or int(turn.tray[k]) > 0
	if not has_jokers:
		await get_tree().create_timer(Motion.secs(timing.ending)).timeout
		while busy and id == _dead_id:
			await get_tree().create_timer(0.1).timeout
		if id == _dead_id and dead and not over:
			send({"endTurn": {}})
		return
	grace_left = GRACE_SECONDS
	changed.emit()
	while id == _dead_id and grace_left >= 0:
		await get_tree().create_timer(1.0).timeout
		if id != _dead_id:
			return
		if over or not dead:
			grace_left = -1
			changed.emit()
			return
		if busy or mode != "trace" or warning != null or info != "":
			continue
		if grace_left <= 1:
			grace_left = -1
			send({"endTurn": {}})
			return
		grace_left -= 1
		changed.emit()

func _finish() -> void:
	_timer.stop()
	_reach_timer.stop()
	game = JSON.parse_string(engine.gameState())

# MARK: Toasts and the feed

func _show(text: String) -> void:
	toast = text
	_toast_id += 1
	var id := _toast_id
	toast_changed.emit()
	await get_tree().create_timer(Motion.wait("toast") / 1000.0).timeout
	if id == _toast_id:
		toast = ""
		toast_changed.emit()

func show_toast(text: String) -> void:
	_show(text)

func _line(text: String) -> void:
	feed.push_front(text)

func _faces(refs: Array) -> String:
	return " ".join(refs.map(func(r): return CardArt.face(r.card)))

func _describe(e: Dictionary) -> void:
	var k: String = e.keys()[0]
	var f: Dictionary = e[k]
	match k:
		"traceRejected":
			_show({"size": "Sets are 2 to %d cards" % pick_limit(), "special": "A special joker can't be in a set",
				"no_grid_card": "Every set needs a grid card", "not_touching": "The cards must touch",
				"already_scored": "That set already scored"}.get(f.reason, f.reason))
		"leftoverWarning":
			var ps: Array = f.positions.map(Board.parse_pos)
			var v = JSON.parse_string(engine.preview(JSON.stringify(ps))).get("value")
			warning = v.leftOverPositions.map(func(p): return CardArt.face(cell(int(p)).card)) if v != null else []
		"leftoverPenalty":
			var faces := " ".join(f.positions.map(func(n): return CardArt.face(cell(Board.parse_pos(n)).card) if cell(Board.parse_pos(n)) != null else n))
			_line("%s  no combo: %s left over  −%d" % [faces, faces, f.cost])
		"score":
			last_score = f
			var names := " ".join(f.cards.map(func(c): return CardArt.face(c.card)))
			_line("%s  %s: %s  %+d" % [names, "multi" if f.multi else "single", " + ".join(f.combos.map(combo_name)), f.points])
		"extraDrawn":
			var where_: String = {"board": "on the board", "stock": "shuffled into the stock", "tray": "to your tray", "steps": ""}.get(f.goes, f.goes)
			var kind: String = {"amber": "Amber joker", "teal": "Teal joker", "title": "Title card", "blank": "Blank card"}.get(f.card.card, f.card.card.capitalize())
			var text: String = f.prize if f.outcome == "steps" else "%s %s" % [CardArt.face(f.prize) if CardArt.is_playing(f.prize) else f.prize, where_]
			_line("%s: %s (%s)" % [kind, text, f.tier])
			_show("%s: %s" % [kind, text])
		"swap":
			_line("Swapped %s  to  %s" % [_faces(f.before), _faces(f.after)])
		"bomb":
			_line("Bomb: cleared " + _faces(f.cleared))
		"burn":
			_line("Burned %s: out of the deck for the game (%d cards)" % [_faces([f.card]), f.deckSize])
			_show("Burned %s for the game" % _faces([f.card]))
		"stockOut":
			_line(("Stock empty" if f.reason == "stock_empty" else "Card budget used") + ": play out the board")
		"reach":
			_line("Reach: hand size +%d for %d s (now %d)" % [f.cards, f.seconds, f.pickLimit])
			_show("Reach: hand size +%d for %d s" % [f.cards, f.seconds])
		"reachOver":
			_line("Reach over: hand size back to %d" % f.pickLimit)
		"noSetsLeft":
			var any := false
			for t in f.tray:
				any = any or int(f.tray[t]) > 0
			_show("No sets score: use a power joker" if any else "No sets score")
		"boardCleared":
			_line("Board cleared! +%d steps" % f.amount)
		"prizeWon":
			_line("Prize: %s (best set %d), wins a %s" % [f.tier, f.bestPoints, f.special])
		"turnEnd":
			_line("%s: %d steps" % [{"player": "You ended the turn", "timer": "Time's up", "board_cleared": "Board cleared"}.get(f.reason, f.reason), f.totals.steps])
