extends RefCounted
class_name GameConfig

const W := 960.0
const H := 720.0
const HUD := 76.0
const PLAY_H := H - HUD
const PLAYER_Y := H - 58.0

const SPRITE_SHEET_SIZE := 1254.0
const SPRITE_GRID := 4.0
const SPRITE_CELL := SPRITE_SHEET_SIZE / SPRITE_GRID
const SPRITE_PAD := 12.0

const STAGES := [
	{"name": "STAR DRIFT", "bg": 0, "rows": 3, "cols": 8, "kinds": ["bug", "bug", "diver"], "speed": 24.0, "fire": 0.62, "dive": 0.45, "boss": false, "stars": 0.86, "scroll": 0.82, "tint": Color("#91dfff")},
	{"name": "VENOM NEBULA", "bg": 1, "rows": 4, "cols": 8, "kinds": ["bug", "zig", "diver"], "speed": 32.0, "fire": 0.86, "dive": 0.8, "boss": false, "stars": 1.0, "scroll": 1.0, "tint": Color("#c77cff")},
	{"name": "ROCK BELT", "bg": 2, "rows": 4, "cols": 9, "kinds": ["armor", "bug", "zig"], "speed": 36.0, "fire": 1.05, "dive": 1.0, "boss": false, "stars": 1.08, "scroll": 1.12, "tint": Color("#ffe36e")},
	{"name": "PLASMA NEST", "bg": 3, "rows": 5, "cols": 9, "kinds": ["saucer", "zig", "armor", "diver"], "speed": 42.0, "fire": 1.2, "dive": 1.35, "boss": false, "stars": 1.18, "scroll": 1.24, "tint": Color("#ff69d8")},
	{"name": "CITADEL CORE", "bg": 4, "rows": 0, "cols": 0, "kinds": [], "speed": 0.0, "fire": 0.0, "dive": 0.0, "boss": true, "stars": 1.3, "scroll": 1.38, "tint": Color("#ff5f46")},
]

const ENEMY_STATS := {
	"bug": {"hp": 1, "score": 120, "size": 34.0, "color": Color("#78ff69"), "role": "drone"},
	"diver": {"hp": 1, "score": 240, "size": 44.0, "color": Color("#b76cff"), "role": "diver"},
	"zig": {"hp": 1, "score": 180, "size": 36.0, "color": Color("#39eaff"), "role": "weaver"},
	"armor": {"hp": 2, "score": 420, "size": 46.0, "color": Color("#8dff5d"), "role": "tank"},
	"saucer": {"hp": 1, "score": 360, "size": 44.0, "color": Color("#ff57f0"), "role": "flanker"},
	"commander": {"hp": 7, "score": 1600, "size": 64.0, "color": Color("#ff5ff0"), "role": "commander"},
}

const UPGRADE_POOL := [
	{"id": "rapid", "name": "RAPID ARRAY", "desc": "SHOT RATE UP"},
	{"id": "overdrive", "name": "CORE EXTENDER", "desc": "OVERDRIVE TIME UP"},
	{"id": "resonance", "name": "GRAZE AMP", "desc": "RESONANCE GAIN UP"},
	{"id": "bomb", "name": "BOMB LENS", "desc": "BOMB WIDTH UP"},
	{"id": "shield", "name": "SHIELD CELL", "desc": "SHIELD MAX UP"},
	{"id": "drop", "name": "SALVAGE LINK", "desc": "ITEM DROP UP"},
]

const BG_PANELS := [
	Rect2(14, 12, 599, 431),
	Rect2(642, 12, 599, 431),
	Rect2(14, 462, 599, 403),
	Rect2(642, 462, 599, 403),
	Rect2(14, 881, 1227, 359),
]

const DIGIT_MAP := {
	"0": ["111", "101", "101", "101", "111"],
	"1": ["010", "110", "010", "010", "111"],
	"2": ["111", "001", "111", "100", "111"],
	"3": ["111", "001", "111", "001", "111"],
	"4": ["101", "101", "111", "001", "001"],
	"5": ["111", "100", "111", "001", "111"],
	"6": ["111", "100", "111", "101", "111"],
	"7": ["111", "001", "010", "010", "010"],
	"8": ["111", "101", "111", "101", "111"],
	"9": ["111", "101", "111", "001", "111"],
	" ": ["000", "000", "000", "000", "000"],
}


static func sprite_cell(col: int, row: int, pad := SPRITE_PAD) -> Rect2:
	return Rect2(col * SPRITE_CELL + pad, row * SPRITE_CELL + pad, SPRITE_CELL - pad * 2.0, SPRITE_CELL - pad * 2.0)


static func sprites() -> Dictionary:
	return {
		"player": sprite_cell(0, 0),
		"bug": sprite_cell(1, 0),
		"diver": sprite_cell(2, 0),
		"zig": sprite_cell(3, 0),
		"armor": sprite_cell(0, 1),
		"saucer": sprite_cell(1, 1),
		"bomb": sprite_cell(2, 1),
		"laser": sprite_cell(3, 1),
		"orb": sprite_cell(0, 2),
		"boom1": sprite_cell(1, 2),
		"boom2": sprite_cell(2, 2),
		"boom3": sprite_cell(3, 2),
		"boss": sprite_cell(0, 3),
		"turret": sprite_cell(1, 3),
		"core": sprite_cell(2, 3),
		"flame": sprite_cell(3, 3),
	}
