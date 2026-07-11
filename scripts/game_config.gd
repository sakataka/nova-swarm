extends RefCounted
class_name GameConfig

const W := 960.0
const H := 720.0
const HUD := 76.0
const PLAY_H := H - HUD
const PLAYER_Y := H - 58.0
const PLAYER_MIN_Y := HUD + 206.0
const PLAYER_MAX_Y := H - 44.0

const SPRITE_SHEET_SIZE := 1254.0
const SPRITE_GRID := 4.0
const SPRITE_CELL := SPRITE_SHEET_SIZE / SPRITE_GRID
const SPRITE_PAD := 12.0

const UI_BG := Color("#050816")
const UI_PANEL := Color("#0b1530")
const UI_PANEL_DARK := Color("#030611")
const UI_TEXT := Color("#f7fbff")
const UI_TEXT_DIM := Color(0.72, 0.82, 0.94, 0.72)
const UI_CYAN := Color("#42d9ff")
const UI_RED := Color("#ff4d6d")
const UI_DEEP_RED := Color("#35112a")
const UI_MAGENTA := Color("#a95cff")
const UI_AMBER := Color("#ffb84d")
const UI_GREEN := Color("#7cff6b")
const UI_PANEL_ALPHA := 0.84
const UI_LINE_ALPHA := 0.52
const UI_TOUCH_SHOT_SIZE := 112.0
const UI_TOUCH_BOMB_SIZE := 88.0
const UI_TOUCH_OVERDRIVE_SIZE := 84.0
const UI_TOUCH_PAUSE_SIZE := 66.0
const UI_TOUCH_STICK_RADIUS := 92.0
const UI_TOUCH_STICK_HIT := 222.0
const UI_TOUCH_KNOB := 28.0

const STAGES := [
	{"name": "AURORA GATE", "bg": 0, "rows": 3, "cols": 7, "waves": 5, "midbosses": 0, "kinds": ["bug", "bug", "diver"], "speed": 22.0, "fire": 0.54, "dive": 0.38, "boss": false, "stars": 0.86, "scroll": 0.82, "tint": Color("#79dfff")},
	{"name": "VIOLET FRONT", "bg": 1, "rows": 3, "cols": 8, "waves": 6, "midbosses": 0, "kinds": ["bug", "zig", "diver"], "speed": 29.0, "fire": 0.72, "dive": 0.62, "boss": false, "stars": 0.95, "scroll": 0.96, "tint": Color("#aa8cff")},
	{"name": "TWIN COMET", "bg": 1, "rows": 3, "cols": 7, "waves": 4, "midbosses": 2, "kinds": ["zig", "diver", "armor"], "speed": 33.0, "fire": 0.84, "dive": 0.78, "boss": false, "stars": 1.02, "scroll": 1.04, "tint": Color("#ff79cb")},
	{"name": "SOLAR BREAK", "bg": 2, "rows": 4, "cols": 8, "waves": 5, "midbosses": 0, "kinds": ["armor", "saucer", "zig", "diver"], "speed": 36.0, "fire": 0.94, "dive": 0.92, "boss": false, "stars": 1.08, "scroll": 1.12, "tint": Color("#ffd07a")},
	{"name": "TRINITY SIEGE", "bg": 3, "rows": 4, "cols": 8, "waves": 4, "midbosses": 3, "kinds": ["saucer", "zig", "armor", "diver"], "speed": 39.0, "fire": 1.06, "dive": 1.08, "boss": false, "stars": 1.16, "scroll": 1.22, "tint": Color("#ff6f9e")},
	{"name": "NOVA SOVEREIGN", "bg": 4, "rows": 0, "cols": 0, "waves": 1, "midbosses": 0, "kinds": [], "speed": 0.0, "fire": 0.0, "dive": 0.0, "boss": true, "stars": 1.26, "scroll": 1.34, "tint": Color("#6ea5ff")},
]

const ENEMY_STATS := {
	"bug": {"hp": 1, "score": 120, "size": 34.0, "color": Color("#78ff69"), "role": "drone"},
	"diver": {"hp": 2, "score": 240, "size": 44.0, "color": Color("#b76cff"), "role": "diver"},
	"zig": {"hp": 2, "score": 180, "size": 36.0, "color": Color("#39eaff"), "role": "weaver"},
	"armor": {"hp": 3, "score": 420, "size": 46.0, "color": Color("#8dff5d"), "role": "tank"},
	"saucer": {"hp": 2, "score": 360, "size": 44.0, "color": Color("#ff57f0"), "role": "flanker"},
	"commander": {"hp": 14, "score": 1600, "size": 64.0, "color": Color("#ff5ff0"), "role": "commander"},
	"mid_lancer": {"hp": 250, "score": 5200, "size": 76.0, "color": Color("#ff5a7a"), "role": "midboss"},
	"mid_orbit": {"hp": 280, "score": 5600, "size": 78.0, "color": Color("#a96cff"), "role": "midboss"},
	"mid_anchor": {"hp": 330, "score": 6200, "size": 82.0, "color": Color("#ffb84d"), "role": "midboss"},
}

const CHIP_TRACKS := {
	"power": {"name": "POWER", "color": Color("#ff6b54"), "shape": "triangle"},
	"spread": {"name": "SPREAD", "color": Color("#7cff6b"), "shape": "fan"},
	"resonance": {"name": "RESONANCE", "color": Color("#ffd84a"), "shape": "hex"},
}

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
