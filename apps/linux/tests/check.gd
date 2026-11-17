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

	print("%d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
