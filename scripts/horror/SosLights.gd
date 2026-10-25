# File: res://scripts/horror/SosLights.gd
# The corridor emergency lights after the third fuse (spec H-D5): red, flashing SOS in Morse (· · · — — — · · ·) on a loop:
# dot 0.2 s, dash 0.6 s, gap inside a letter 0.2 s, letter gap 0.6 s, word gap 1.4 s (one loop = 6.8 s). Emissive only:
# it changes the materials' emission energy and colour (no light node, no shader switch). "Giảm hù dọa": a slow red
# pulse that never goes dark (no strobe).
# pattern() / is_on_at(t) are pure (tests). The level hands it the corridor materials (NightBuildingMap "corridor_lights")
# after taking them away from the ScareDirector's flicker (drop_light_groups).
class_name SosLights
extends Node

const DOT: float = 0.2
const DASH: float = 0.6
const GAP: float = 0.2
const LETTER_GAP: float = 0.6
const WORD_GAP: float = 1.4
const RED := Color("#FF2A1E")
const ON_ENERGY: float = 3.2
const OFF_ENERGY: float = 0.05
## Reduced: a slow pulse (period PULSE_S) between these energies.
const PULSE_S: float = 3.0
const PULSE_LO: float = 0.6
const PULSE_HI: float = 2.0

var mats: Array[StandardMaterial3D] = []
var reduce_scares: bool = false
var t: float = 0.0
var running: bool = false
var auto_tick: bool = true
## Light state now (tests): on / off for SOS, the energy for both variants.
var lit: bool = false
var energy: float = 0.0


func _init() -> void:
	name = "SosLights"


## Segments of one loop: [[on: bool, seconds], ...] (S, letter gap, O, letter gap, S, word gap).
static func pattern() -> Array:
	var out: Array = []
	var letters: Array = [[DOT, DOT, DOT], [DASH, DASH, DASH], [DOT, DOT, DOT]]
	for li: int in letters.size():
		var marks: Array = letters[li]
		for mi: int in marks.size():
			out.append([true, float(marks[mi])])
			if mi < marks.size() - 1:
				out.append([false, GAP])
		out.append([false, LETTER_GAP if li < letters.size() - 1 else WORD_GAP])
	return out


static func period() -> float:
	var s: float = 0.0
	for seg: Array in pattern():
		s += float(seg[1])
	return s


## SOS light state at time t (s, loops).
static func is_on_at(time: float) -> bool:
	var p: float = period()
	var x: float = fposmod(time, p)
	for seg: Array in pattern():
		var d: float = float(seg[1])
		if x < d:
			return bool(seg[0])
		x -= d
	return false


## Takes the materials over (red) and starts the loop.
func start(materials: Array, reduced: bool) -> void:
	mats.clear()
	for m: Variant in materials:
		if m is StandardMaterial3D:
			mats.append(m)
	reduce_scares = reduced
	t = 0.0
	running = true
	for m2: StandardMaterial3D in mats:
		m2.emission_enabled = true
		m2.albedo_color = RED
		m2.emission = RED
	tick(0.0)


func stop() -> void:
	running = false


## Energy at time `time` for the reduced variant (a slow pulse, never dark).
static func pulse_energy(time: float) -> float:
	return lerpf(PULSE_LO, PULSE_HI, 0.5 - 0.5 * cos(TAU * time / PULSE_S))


func tick(delta: float) -> void:
	if not running:
		return
	t += delta
	if reduce_scares:
		lit = true
		energy = pulse_energy(t)
	else:
		lit = is_on_at(t)
		energy = ON_ENERGY if lit else OFF_ENERGY
	for m: StandardMaterial3D in mats:
		m.emission_energy_multiplier = energy


func _process(delta: float) -> void:
	if auto_tick:
		tick(delta)
