extends Control
## Placeholder until the match turn scene lands: the build line and an engine check.

func _ready() -> void:
	var engine = ClassDB.instantiate("CribEngine")
	var v = JSON.parse_string(engine.versions())
	var line := "Linux %s · spec %s · %s" % [ProjectSettings.get_setting("application/config/version"), v.spec, v.rules.trim_prefix("match-")]
	var err: String = engine.loadConfig(Repo.path("cribbage/minigames/config"))
	$Line.text = line if err == "" else "Config didn't load: " + err
