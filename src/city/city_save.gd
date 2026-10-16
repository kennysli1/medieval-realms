class_name CitySave
extends RefCounted

const Simulation = preload("res://src/city/city_simulation.gd")
const PATH: String = "user://saves/city.json"
static var last_error: String = ""

static func save_city(sim: RefCounted, path: String = PATH) -> bool:
	last_error = ""
	var directory := ProjectSettings.globalize_path(path.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		last_error = "无法创建存档目录"
		return false
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_error = "无法写入临时存档"
		return false
	file.store_string(JSON.stringify(sim.export_state()))
	file.flush()
	file.close()
	if load_city(temporary) == null:
		last_error = "临时存档校验失败，原存档已保留"
		return false
	var absolute := ProjectSettings.globalize_path(path)
	var backup := absolute + ".bak"
	if FileAccess.file_exists(path):
		if DirAccess.copy_absolute(absolute, backup) != OK:
			last_error = "备份失败，原存档已保留"
			return false
		if DirAccess.remove_absolute(absolute) != OK:
			last_error = "无法替换存档，备份已保留"
			return false
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), absolute) != OK:
		if FileAccess.file_exists(backup):
			DirAccess.copy_absolute(backup, absolute)
		last_error = "存档替换失败，请检查磁盘权限"
		return false
	return true

static func load_city(path: String = PATH) -> RefCounted:
	last_error = ""
	if not FileAccess.file_exists(path):
		last_error = "还没有存档，请先保存城镇"
		return null
	if FileAccess.get_file_as_bytes(path).size() > 10_000_000:
		last_error = "存档超过容量限制"
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		last_error = "存档格式损坏；当前城镇保持不变，可尝试恢复备份"
		return null
	var sim = Simulation.new()
	if not sim.import_state(parsed):
		last_error = "存档版本或内容无效；当前城镇保持不变"
		return null
	return sim
