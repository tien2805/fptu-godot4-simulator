# File: res://scripts/horror/HorrorSenses.gd
# What the stalkers know about the player (spec B-D3), written by HorrorKit every physics frame (tests write it directly):
# pos = the player's feet (the hiding spot's exit point while hidden), hidden + spot, lit = flashlight on with charge (sight
# range 22 m instead of 14 m), noise = hearing radius in metres (sprint 10, jog 6, walk on Ctrl 3, still or hidden 0),
# grace = catch grace after leaving a hiding spot.
class_name HorrorSenses
extends RefCounted

var pos: Vector3 = Vector3.ZERO
var hidden: bool = false
var spot: Node3D = null
var lit: bool = false
var noise: float = 0.0
## Seconds of catch grace left (just after leaving a hiding spot: no landing on an unseen stalker).
var grace: float = 0.0
