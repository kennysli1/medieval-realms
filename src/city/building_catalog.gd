class_name BuildingCatalog
extends RefCounted

const ORDER: Array[String] = ["house", "warehouse", "woodcutter", "sawmill", "farm"]
const DEFINITIONS: Dictionary = {
	"keep": {"name": "领主府", "size": 3, "atlas": 0, "cost": {}, "description": "城镇的起点。升级需要 40 木板，增加领地声望。"},
	"house": {"name": "居民住宅", "size": 2, "atlas": 1, "cost": {"wood": 12}, "description": "提供 12 人住房。空闲居民会沿街散步与休息。"},
	"warehouse": {"name": "仓库", "size": 2, "atlas": 2, "cost": {"wood": 20, "planks": 6}, "description": "货物交接站。产业必须接入领主府旁的主仓库路网。"},
	"woodcutter": {"name": "伐木场", "size": 2, "atlas": 3, "cost": {"wood": 16}, "description": "两名工人采集原木，搬运入仓后才计入库存。"},
	"sawmill": {"name": "锯木厂", "size": 2, "atlas": 4, "cost": {"wood": 20, "planks": 4}, "description": "两名木匠从仓库取 2 原木，制成 3 木板并运回。"},
	"farm": {"name": "麦田农舍", "size": 2, "atlas": 5, "cost": {"wood": 14}, "description": "两名农夫耕种，每批收获 6 食物，供居民生活。"}
}

static func definition(kind: String) -> Dictionary:
	return DEFINITIONS.get(kind, {})

static func cost_text(cost: Dictionary) -> String:
	var pieces: PackedStringArray = []
	for resource in cost:
		pieces.append("%s %d" % [resource_name(resource), cost[resource]])
	return " · ".join(pieces)

static func resource_name(key: String) -> String:
	return {"wood": "原木", "planks": "木板", "food": "食物"}.get(key, key)
