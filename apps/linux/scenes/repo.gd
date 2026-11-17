class_name Repo
## Paths to the shared data, read where it lives in the repo (PORTING.md › Layout: never copied).

static func root() -> String:
	return ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()

static func path(relative: String) -> String:
	return root().path_join(relative)

static func read_json(relative: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path(relative)))
