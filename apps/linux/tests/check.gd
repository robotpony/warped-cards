extends SceneTree
## Headless check for the Linux client (apps/linux/scripts/check.sh). Exits 1 on any failure.
## It checks the bridge, not the engine's rules: engine/swift's own tests and the fixtures do that.

var failures := 0

func expect(ok: bool, what: String) -> void:
	print(("ok    " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1

func _initialize() -> void:
	var engine = ClassDB.instantiate("CribEngine")
	expect(engine != null, "the extension loads and registers CribEngine")
	if engine == null:
		quit(1)
		return

	var v = JSON.parse_string(engine.versions())
	var spec = Repo.read_json("cribbage/minigames/spec.json")
	var rules = Repo.read_json("cribbage/minigames/config/rules.json")
	expect(int(v.spec) == int(spec.specVersion), "the engine implements spec %s, as spec.json says" % v.spec)
	expect(v.rules == rules.rulesVersion, "the engine plays %s, as rules.json says" % v.rules)

	var err: String = engine.loadConfig(Repo.path("cribbage/minigames/config"))
	expect(err == "", "config loads from the shared folder " + err)

	var folder := Repo.path("cribbage/minigames/fixtures/records")
	var records := Array(DirAccess.get_files_at(folder)).filter(func(f): return f.ends_with(".jsonl"))
	expect(records.size() > 0, "golden records found: %d" % records.size())
	for f in records:
		var r: String = engine.verifyRecord(folder.path_join(f))
		expect(r.begins_with("ok"), "golden record %s verifies: %s" % [f, r])

	# A game through the bridge: actions go in as engine.md JSON, steps come back the same way.
	var opening = JSON.parse_string(engine.newGame(1, "classic"))
	expect(opening.has("events") and opening.seq == 1, "a new game opens with step 1")
	var step = JSON.parse_string(engine.send('{"startHand":{"options":{"deal":true,"warned":true}}}', 0, 0))
	var dealt := false
	if step.has("events"):
		for e in step.events:
			dealt = dealt or e.has("deal")
	expect(dealt, "startHand deals a hand")
	var bad = JSON.parse_string(engine.send('{"nonsense":{}}', 0, 0))
	expect(bad.has("error"), "an unreadable action is refused, not ignored")

	# What the screen reads between steps (apps/linux/README.md › The bridge). Seed 1 with the deal
	# off: g02 is 8♥ and g03 is 7♣, a fifteen (docs/images/reference/README.md › trace-combo).
	engine.newGameWith(1, "classic", true, true)
	engine.send('{"startHand":{"options":{"deal":false,"warned":false}}}', 0, 0)
	var t = JSON.parse_string(engine.turnState())
	expect(t.cells.size() == 25 and t.cells[2].card == "8H" and t.cells[3].card == "7C", "turnState holds the board by position")
	expect(int(t.pickLimit) == int(rules.match.maxSet) and t.starterJoins, "turnState gives the pick limit and the starter rule")
	var pv = JSON.parse_string(engine.preview("[2,3]"))
	expect(not pv.has("problem") and pv.value.combos.size() == 1 and pv.value.combos[0].kind == "fifteen" and int(pv.value.points) == 2,
		"preview counts 8♥ 7♣ as a fifteen for 2")
	var far = JSON.parse_string(engine.preview("[0,3]"))
	expect(far.get("problem") == "not_touching", "preview names the rule a trace breaks")
	expect(engine.isLine("[0,1,2]") and not engine.isLine("[0,5,2]"), "isLine knows a straight line")
	var g = JSON.parse_string(engine.gameState())
	expect(g.stage == "playing" and int(g.turn) == 1 and int(g.deck.count) == 52, "gameState gives the stage, the turn and the deck")
	var before := int(t.steps)
	engine.send('{"trace":{"positions":[2,3]}}', 0, 1000)
	expect(int(JSON.parse_string(engine.turnState()).steps) == before + 2, "a trace sent through the bridge scores")

	var fx = Repo.read_json("cribbage/minigames/config/fx.json")
	expect(fx != null and fx.has("motions") and fx.has("waits"), "config/fx.json loads (ui.md › Motion: a client MUST NOT start without it)")
	var line := "Linux %s · spec %s · %s" % [ProjectSettings.get_setting("application/config/version"), v.spec, v.rules.trim_prefix("match-")]
	print("build line: " + line)

	print("%d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
