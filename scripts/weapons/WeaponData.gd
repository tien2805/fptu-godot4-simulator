# File: res://scripts/weapons/WeaponData.gd
# Weapon table of Phase W (spec 2026-10-23-phase-w-weapons-wanted-design.md, W-D4, section 3). Slot order = wheel order
# (slot 0 at the top, clockwise). mag 0 = no magazine (melee, thrown, loa). Times in game seconds (Engine.time_scale applies).
# Plan decisions: shotgun reload 2.4 s (P2), heat per shot (P3).
class_name WeaponData
extends RefCounted

enum Slot { UNARMED, KNIFE, PISTOL, SHOTGUN, ROCKET, DEP, DURIAN, LOA }

const COUNT: int = 8
const SLOTS: Array[Dictionary] = [
	{"id": "unarmed", "name": "Tay không", "kind": "melee", "mag": 0, "cycle": 0.35, "reload": 0.0, "auto": true, "range": 1.3, "half_deg": 50.0},
	{"id": "knife", "name": "Dao", "kind": "melee", "mag": 0, "cycle": 0.5, "reload": 0.0, "auto": true, "range": 1.4, "half_deg": 60.0},
	{"id": "pistol", "name": "Súng lục", "kind": "hitscan", "mag": 12, "cycle": 0.25, "reload": 1.6, "auto": true, "range": 80.0, "spread_aim": 0.5, "spread_hip": 3.5},
	{"id": "shotgun", "name": "Shotgun", "kind": "pellets", "mag": 6, "cycle": 0.8, "reload": 2.4, "auto": true, "range": 30.0, "pellets": 8, "cone_deg": 9.0, "spread_hip": 4.0, "knockback": 4.0},
	{"id": "rocket", "name": "Tên lửa", "kind": "rocket", "mag": 1, "cycle": 0.3, "reload": 2.5, "auto": false, "speed": 35.0, "radius": 6.0, "range": 140.0},
	{"id": "dep", "name": "Dép tổ ong", "kind": "boomerang", "mag": 0, "cycle": 0.2, "reload": 0.0, "auto": false, "reach": 12.0},
	{"id": "durian", "name": "Sầu riêng", "kind": "grenade", "mag": 0, "cycle": 1.0, "reload": 0.0, "auto": false, "fuse": 2.0, "cloud_r": 4.0, "cloud_s": 6.0},
	{"id": "loa", "name": "Loa kẹo kéo", "kind": "cone", "mag": 0, "cycle": 0.2, "reload": 0.0, "auto": true, "range": 10.0, "half_deg": 30.0},
]

## Heat (spec section 3; WantedDirector adds +5 for an officer knocked out).
const HEAT_KO_UNARMED: float = 1.0
const HEAT_KNIFE: float = 2.0
const HEAT_SHOT_NEAR: float = 2.0
const HEAT_PISTOL_HIT: float = 2.0
const HEAT_SHOTGUN: float = 3.0
const HEAT_ROCKET: float = 6.0
const HEAT_DEP: float = 1.0
const HEAT_DURIAN: float = 2.0
const HEAT_LOA_PER_2S: float = 1.0
## "Near people" for the shot heat: a pedestrian or officer within this many metres of the player.
const NEAR_PEOPLE_M: float = 15.0


static func name_of(slot: int) -> String:
	return String(SLOTS[clampi(slot, 0, COUNT - 1)]["name"])


static func mag_of(slot: int) -> int:
	return int(SLOTS[clampi(slot, 0, COUNT - 1)]["mag"])


## Wheel / HUD ammo text: "12 / ∞" for magazine weapons (unlimited reserve, W-D9), "∞" otherwise.
static func ammo_text(slot: int, left: int) -> String:
	return "%d / ∞" % left if mag_of(slot) > 0 else "∞"
