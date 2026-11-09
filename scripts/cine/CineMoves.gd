# File: res://scripts/cine/CineMoves.gd
# Logical moves for cinematics (spec A1-D4, A1-D22). A move has a fixed STORY duration and an impact fraction hit_u; at run
# time it resolves to the best available tier (Mixamo -> UAL -> native body clip -> code pose). Each tier's clip window
# [from, hit, to] is mapped piecewise-linearly onto the move so its impact frame lands at story time start + hit_u·dur:
# blocking, timing and the beat sheet are the same whichever tier plays. Entry extras ("arc" metres, "spin" degrees per axis)
# add the airborne height / rotation a tier lacks over the move's "air" window; "add" layers an additive code pose; "yaw"
# turns the actor while that entry plays; "ref" is the clip time whose hips position the horizontal root strip keeps (default
# from; 0 keeps a mid-clip hold window over the root when the clip travelled before it). to = -1 -> full clip; from > to ->
# backwards. Code entries play pose-u 0..1 and
# may carry "hit" (pose-u of their impact), mapped like a clip window; additive layers peak on the impact (add_u).
# Native windows are authored in seconds of the men/* body clips; women/* body files hold the same keys stretched in time
# (every clip 1.25x longer), so resolve() scales native windows by the rig's Death length over NATIVE_REF_LEN.
class_name CineMoves
extends RefCounted

const TIERS: Array[String] = ["mixamo", "ual", "native", "code"]
## Test hook: best tier allowed (index into TIERS). If no entry passes the cap, the last available entry is used.
static var max_tier: int = 0
## Reference native clip and its length (s) on the men/* rigs the native windows below were authored on.
const NATIVE_REF_CLIP: String = "Death"
const NATIVE_REF_LEN: float = 1.0666667
## Hip-height pivot of CineActor's spin node (= CineActor.PIVOT_Y): code poses that lay the body down drop it by this much.
const PIVOT_Y: float = 0.95
## Height of the pivot above the ground when lying flat (half the body's thickness at the hips; Task 7: hips bone ~0.14 m,
## like the clip tiers' lying frames at 0.10-0.13 m).
const LIE_PIVOT_Y: float = 0.08
## Pose-u of the code poses' impact (striking foot at full reach, measured on the evaluated actor): code entries carry it as
## "hit" so the move's hit_u maps onto it exactly like a clip window (clip_time with from 0, to 1).
const FLYING_KICK_HIT: float = 0.75
const SPIN_KICK_HIT: float = 0.7
## Additive layers ("add") peak at pose-u ADD_HIT; add_u() maps the move's hit_u onto it, so the delta peaks on the impact
## and is zero at both window ends (no pop).
const ADD_HIT: float = 0.5

const MOVES: Dictionary = {
	"fight_idle": {"dur": 3.3, "loop": true, "src": [
		{"t": "mixamo", "a": "Fighting_Idle", "from": 0.0, "to": 3.3}, {"t": "ual1", "a": "Idle"},
		{"t": "native", "a": "Idle"}, {"t": "code", "a": "stance"}]},
	"taunt": {"dur": 1.6, "src": [
		{"t": "mixamo", "a": "Taunt"}, {"t": "ual2", "a": "Idle_No"}, {"t": "native", "a": "Wave"}, {"t": "code", "a": "taunt"}]},
	"sprint": {"dur": 0.533, "loop": true, "src": [
		{"t": "mixamo", "a": "Sprint"}, {"t": "ual1", "a": "Sprint"}, {"t": "native", "a": "Run"}]},
	"jog": {"dur": 0.8, "loop": true, "src": [{"t": "ual1", "a": "Jog_Fwd"}, {"t": "native", "a": "Run"}]},
	"walk": {"dur": 1.0, "loop": true, "src": [{"t": "ual1", "a": "Walk"}, {"t": "native", "a": "Walk"}]},
	"flying_kick": {"dur": 1.0, "hit_u": 0.55, "air": [0.15, 0.6], "src": [
		{"t": "mixamo", "a": "Flying_Kick", "from": 0.0, "hit": 0.53, "to": 1.1},
		{"t": "code", "a": "flying_kick", "hit": FLYING_KICK_HIT, "arc": 0.9}]},
	"jab": {"dur": 0.45, "hit_u": 0.55, "src": [
		{"t": "mixamo", "a": "Jab_Cross", "from": 0.15, "hit": 0.40, "to": 0.55},
		{"t": "ual1", "a": "Punch_Jab", "from": 0.0, "hit": 0.22, "to": 0.6},
		{"t": "native", "a": "Punch_Left", "from": 0.0, "hit": 0.57, "to": 0.83}]},
	"cross": {"dur": 0.5, "hit_u": 0.5, "src": [
		{"t": "mixamo", "a": "Jab_Cross", "from": 0.50, "hit": 0.67, "to": 0.95},
		{"t": "ual1", "a": "Punch_Cross", "from": 0.1, "hit": 0.3, "to": 0.7},
		{"t": "native", "a": "Punch_Right", "from": 0.0, "hit": 0.57, "to": 0.83}]},
	"hook": {"dur": 0.7, "hit_u": 0.55, "src": [
		{"t": "mixamo", "a": "Hook_Punch", "from": 0.6, "hit": 1.0, "to": 1.4},
		{"t": "ual2", "a": "Melee_Hook", "from": 0.0, "hit": 0.25, "to": 0.47},
		{"t": "native", "a": "Punch_Right", "from": 0.0, "hit": 0.57, "to": 0.83}]},
	"uppercut": {"dur": 0.8, "hit_u": 0.5, "src": [
		{"t": "mixamo", "a": "Uppercut", "from": 0.2, "hit": 0.49, "to": 0.95},
		{"t": "ual1", "a": "Punch_Jab", "from": 0.0, "hit": 0.2, "to": 0.6, "add": "uppercut"},
		{"t": "native", "a": "Punch_Left", "from": 0.0, "hit": 0.57, "to": 0.83, "add": "uppercut"}]},
	"roundhouse": {"dur": 1.0, "hit_u": 0.5, "src": [
		{"t": "mixamo", "a": "Roundhouse_Kick", "from": 0.6, "hit": 1.07, "to": 1.6},
		{"t": "native", "a": "Kick_Right", "from": 0.1, "hit": 0.5, "to": 0.93, "add": "spin_kick_add"},
		{"t": "code", "a": "spin_kick", "hit": SPIN_KICK_HIT}]},
	# code tier: the smoothstep spin is half done at the impact (hit_u 0.5), so two turns put the kick on the target at
	# exactly one turn and still end facing forward (one turn would strike while facing away)
	"hurricane_kick": {"dur": 1.2, "hit_u": 0.5, "air": [0.05, 0.95], "src": [
		{"t": "mixamo", "a": "Hurricane_Kick", "from": 0.1, "hit": 0.9, "to": 1.7, "arc": 0.35},
		{"t": "code", "a": "spin_kick", "hit": SPIN_KICK_HIT, "arc": 0.7, "spin": Vector3(0.0, -720.0, 0.0)}]},
	"front_flip": {"dur": 1.2, "hit_u": 0.45, "air": [0.15, 0.85], "src": [
		{"t": "mixamo", "a": "Front_Flip", "from": 0.35, "hit": 0.85, "to": 1.55},
		{"t": "code", "a": "tuck", "arc": 1.4, "spin": Vector3(-360.0, 0.0, 0.0)}]},
	"dodge": {"dur": 0.8, "hit_u": 0.45, "src": [
		{"t": "mixamo", "a": "Dodging", "from": 0.0, "hit": 0.5, "to": 1.2}, {"t": "code", "a": "dodge_lean", "hit": 0.5}]},
	"block": {"dur": 0.8, "hit_u": 0.4, "src": [
		{"t": "mixamo", "a": "Block", "from": 0.1, "hit": 0.45, "to": 1.2},
		{"t": "ual2", "a": "Sword_Block", "from": 0.0, "hit": 0.2, "to": -1.0}, {"t": "code", "a": "block", "hit": 0.3}]},
	"knee_strike": {"dur": 0.9, "hit_u": 0.5, "air": [0.2, 0.6], "src": [
		{"t": "mixamo", "a": "Knee_Kick", "from": 0.45, "hit": 0.9, "to": 1.35, "arc": 0.25},
		{"t": "native", "a": "Kick_Left", "from": 0.1, "hit": 0.33, "to": 0.93, "add": "knee_add", "arc": 0.4},
		{"t": "code", "a": "knee", "hit": 0.5, "arc": 0.4}]},
	"hit_head": {"dur": 0.6, "hit_u": 0.1, "src": [
		{"t": "mixamo", "a": "Head_Hit", "from": 0.0, "hit": 0.12, "to": 1.0},
		{"t": "ual1", "a": "Hit_Head", "from": 0.0, "hit": 0.06, "to": -1.0},
		{"t": "native", "a": "HitRecieve", "from": 0.0, "hit": 0.06, "to": -1.0}]},
	"hit_stomach": {"dur": 0.6, "hit_u": 0.1, "src": [
		{"t": "mixamo", "a": "Stomach_Hit", "from": 0.0, "hit": 0.1, "to": 1.0},
		{"t": "ual1", "a": "Hit_Chest", "from": 0.0, "hit": 0.06, "to": -1.0},
		{"t": "native", "a": "HitRecieve_2", "from": 0.0, "hit": 0.06, "to": -1.0}]},
	"launched_back": {"dur": 1.6, "hit_u": 0.05, "air": [0.05, 0.55], "src": [
		{"t": "mixamo", "a": "Flying_Back_Death", "from": 0.0, "hit": 0.08, "to": 2.0},
		{"t": "ual2", "a": "Hit_Knockback", "from": 0.0, "hit": 0.04, "to": -1.0, "arc": 0.8},
		{"t": "native", "a": "Death", "from": 0.0, "hit": 0.05, "to": -1.0, "arc": 0.8},
		{"t": "code", "a": "fall_back", "arc": 0.8}]},
	"knocked_out": {"dur": 2.0, "hit_u": 0.05, "src": [
		{"t": "mixamo", "a": "Knocked_Out", "from": 0.6, "hit": 0.7, "to": 4.9, "ref": 0.0},
		{"t": "ual1", "a": "Death01", "from": 0.0, "hit": 0.05, "to": -1.0},
		{"t": "native", "a": "Death", "from": 0.0, "hit": 0.05, "to": -1.0}, {"t": "code", "a": "fall_back"}]},
	"sweep_fall": {"dur": 1.4, "hit_u": 0.35, "src": [
		{"t": "mixamo", "a": "Sweep_Fall", "from": 0.5, "hit": 1.0, "to": 2.5},
		{"t": "ual1", "a": "Death01", "from": 0.0, "hit": 0.3, "to": 2.4, "ref": 0.0},
		{"t": "native", "a": "Death", "from": 0.0, "hit": 0.2, "to": -1.0}, {"t": "code", "a": "fall_back"}]},
	"slip_fall": {"dur": 1.2, "hit_u": 0.3, "src": [
		{"t": "mixamo", "a": "Sweep_Fall", "from": 0.6, "hit": 1.0, "to": 2.5},
		{"t": "ual1", "a": "Death01", "from": 0.0, "hit": 0.3, "to": 2.4, "ref": 0.0},
		{"t": "native", "a": "Death", "from": 0.0, "hit": 0.2, "to": -1.0}, {"t": "code", "a": "fall_back"}]},
	"lie": {"dur": 1.0, "loop": true, "src": [
		# Mixamo: the last lying frame of Flying_Back_Death with the hips kept at their clip-start spot (over the root), the
		# same frame launched_back ends on; Knocked_Out's lying frames sit 1.2 m from the root (crossfades skated)
		{"t": "mixamo", "a": "Flying_Back_Death", "from": 1.97, "to": 2.0, "ref": 0.0},
		{"t": "ual1", "a": "Death01", "from": 2.38, "to": 2.40, "ref": 0.0}, {"t": "native", "a": "Death", "from": 1.05, "to": 1.066},
		{"t": "code", "a": "lie_back"}]},
	"get_up": {"dur": 2.0, "src": [
		{"t": "mixamo", "a": "Getting_Up", "from": 3.0, "to": 8.33},   # 3.0: still half lying (smaller pop out of lie)
		{"t": "ual2", "a": "LayToIdle"}, {"t": "native", "a": "Death", "from": 1.066, "to": 0.0}, {"t": "code", "a": "getup"}]},
	"victory": {"dur": 2.0, "src": [
		{"t": "mixamo", "a": "Victory", "from": 0.5, "to": 2.5}, {"t": "ual2", "a": "Yes"},
		{"t": "native", "a": "Wave"}, {"t": "code", "a": "victory"}]},
	"scissor_takedown": {"dur": 1.1, "hit_u": 0.6, "air": [0.1, 0.65], "src": [
		{"t": "code", "a": "scissor", "arc": 0.8, "spin": Vector3(0.0, 0.0, -80.0)}]},
	# --- grounded brawling (Nobody restage): grabs, shoves, headbutts, throws, tackles. Code poses on every tier (no pack or
	# Mixamo clip covers them), so blocking and contacts are the same whichever tier plays the punches around them.
	"idle": {"dur": 2.5, "loop": true, "src": [
		{"t": "ual1", "a": "Idle"}, {"t": "native", "a": "Idle"}, {"t": "code", "a": "relaxed"}]},
	"shove": {"dur": 0.6, "hit_u": 0.45, "src": [{"t": "code", "a": "shove", "hit": 0.45}]},
	# seg_d3_boss: both hands shove the hanging crane hook at head height (code on every tier)
	"shove_high": {"dur": 0.6, "hit_u": 0.45, "src": [{"t": "code", "a": "shove_high", "hit": 0.45}]},
	"grab": {"dur": 1.0, "loop": true, "src": [{"t": "code", "a": "grab"}]},
	"headbutt": {"dur": 0.6, "hit_u": 0.5, "src": [{"t": "code", "a": "headbutt", "hit": 0.5}]},
	"yank": {"dur": 0.5, "hit_u": 0.45, "src": [{"t": "code", "a": "yank", "hit": 0.45}]},
	"hip_throw": {"dur": 1.0, "hit_u": 0.25, "src": [{"t": "code", "a": "hip_throw", "hit": 0.25}]},
	"thrown": {"dur": 0.7, "hit_u": 0.1, "src": [{"t": "code", "a": "thrown", "hit": 0.1}]},
	"tackle": {"dur": 0.45, "hit_u": 0.6, "src": [{"t": "code", "a": "tackle", "hit": 0.6}]},
	"drive": {"dur": 0.5, "loop": true, "src": [{"t": "code", "a": "drive"}]},
	"doubled": {"dur": 0.6, "loop": true, "src": [{"t": "code", "a": "doubled"}]},
	"stunned": {"dur": 1.2, "loop": true, "src": [{"t": "code", "a": "stunned"}]},
	"winded": {"dur": 1.0, "loop": true, "src": [{"t": "code", "a": "winded"}]},
	"head_shake": {"dur": 0.6, "src": [{"t": "code", "a": "head_shake"}]},
	"neck_crack": {"dur": 0.8, "hit_u": 0.45, "src": [{"t": "code", "a": "neck_crack", "hit": 0.45}]},
	"lie_flat": {"dur": 1.0, "loop": true, "src": [{"t": "code", "a": "lie_back"}]},   # after "thrown" (same pose family)
	# slammed back into something behind him (the scooter), sliding down to sit against it, knees up; and up from there
	"slammed": {"dur": 0.8, "hit_u": 0.05, "src": [{"t": "code", "a": "slammed", "hit": 0.05}]},
	"slumped": {"dur": 2.0, "loop": true, "src": [{"t": "code", "a": "slumped"}]},
	"get_up_sit": {"dur": 1.2, "src": [{"t": "code", "a": "get_up_sit"}]},
	"sit_up": {"dur": 0.5, "src": [{"t": "code", "a": "sit_up"}]},   # from lie_flat up to the slumped sit (W6 seg_d3_boss)
	"pickup": {"dur": 0.5, "hit_u": 0.5, "src": [{"t": "code", "a": "pickup", "hit": 0.5}]},
	# --- story Phase A2 (review A2-R3): a held prop (phone, photo, glasses) raised in front of the chest; sitting on a bench
	# (the actor's key on the ground in front of the seat, pivot dropped to seat height), hands in the lap or one hand up
	# holding a prop; a small nod.
	"hold_up": {"dur": 2.0, "loop": true, "src": [{"t": "code", "a": "hold_up"}]},
	"sit_bench": {"dur": 3.0, "loop": true, "src": [{"t": "code", "a": "sit_bench"}]},
	"sit_bench_hold": {"dur": 3.0, "loop": true, "src": [{"t": "code", "a": "sit_bench_hold"}]},
	"nod": {"dur": 0.8, "src": [{"t": "code", "a": "nod"}]},
	# --- story Phase B (Days 1 and 4): dialogue gestures, the canteen (seated eating / staring, masks going on), the choice
	# scene, Dolly cornered, and the brawl's two-handed chair / pot smash. Code poses on every tier.
	"talk": {"dur": 2.4, "loop": true, "src": [{"t": "code", "a": "talk"}]},
	"point": {"dur": 1.2, "loop": true, "src": [{"t": "code", "a": "point"}]},
	"arms_crossed": {"dur": 3.0, "loop": true, "src": [{"t": "code", "a": "arms_crossed"}]},
	"confess": {"dur": 3.0, "loop": true, "src": [{"t": "code", "a": "confess"}]},
	"phone_call": {"dur": 2.0, "loop": true, "src": [{"t": "code", "a": "phone_call"}]},
	"tray_hold": {"dur": 2.0, "loop": true, "src": [{"t": "code", "a": "tray_hold"}]},
	"eat_sit": {"dur": 1.6, "loop": true, "src": [{"t": "code", "a": "eat_sit"}]},
	"stare_sit": {"dur": 3.0, "loop": true, "src": [{"t": "code", "a": "stare_sit"}]},
	"mask_on": {"dur": 0.9, "src": [{"t": "code", "a": "mask_on"}]},
	"startled": {"dur": 0.7, "src": [{"t": "code", "a": "startled"}]},
	"cornered": {"dur": 2.0, "loop": true, "src": [{"t": "code", "a": "cornered"}]},
	"ride": {"dur": 2.0, "loop": true, "src": [{"t": "code", "a": "ride"}]},
	"step_back": {"dur": 0.6, "src": [{"t": "code", "a": "step_back"}]},
	"chair_smash": {"dur": 0.9, "hit_u": 0.5, "src": [{"t": "code", "a": "chair_smash", "hit": 0.5}]},
	# --- story Phase C (Days 2, 3, 5): seated typing at three laptops (Anh Duy), sipping a coffee (Za Mẫn), a party horn at
	# the mouth (Alexander), tied sitting against a pillar (Sói Xám), the keynote gesture and smug bow (ending C), a
	# two-handed staff guard. Code poses on every tier.
	"type_sit": {"dur": 1.0, "loop": true, "src": [{"t": "code", "a": "type_sit"}]},
	"sip": {"dur": 2.4, "loop": true, "src": [{"t": "code", "a": "sip"}]},
	"blow": {"dur": 1.2, "loop": true, "src": [{"t": "code", "a": "blow"}]},
	"tied_sit": {"dur": 2.0, "loop": true, "src": [{"t": "code", "a": "tied_sit"}]},
	"present": {"dur": 2.4, "loop": true, "src": [{"t": "code", "a": "present"}]},
	"bow_ceo": {"dur": 1.6, "src": [{"t": "code", "a": "bow_ceo"}]},
	"staff_guard": {"dur": 2.0, "loop": true, "src": [{"t": "code", "a": "staff_guard"}]},
	# both hands up over the head holding a weapon across it (Za Mẫn blocks the staff with his katana; UAL2 Sword_Block keeps
	# the hands at the hips, so this is a code pose on every tier)
	"block_high": {"dur": 0.8, "hit_u": 0.45, "src": [{"t": "code", "a": "block_high", "hit": 0.45}]},
	"handshake": {"dur": 1.2, "loop": true, "src": [{"t": "code", "a": "handshake"}]},
	# --- W6 fights (plan 2026-11-05-w6-fights): seg_d4_brawl's tray shield (forearms up, a tray held two-handed in front of
	# the face; code on every tier so the clangs land on the same tray everywhere)
	"tray_guard": {"dur": 1.0, "loop": true, "src": [{"t": "code", "a": "tray_guard"}]},
	# seg_d3_boss's crane-hook ride: hung by the collar off the swinging hook, legs kicking, arms flailing (code on every tier;
	# a strike move: the snag is its first instant)
	"dangle": {"dur": 0.8, "loop": true, "hit_u": 0.0, "src": [{"t": "code", "a": "dangle"}]},
	# --- Q5 acting (plan 2026-10-29-w2-story T5): gestures for the talking actors. The UAL packs have Idle_Talking,
	# Idle_FoldArms and Idle_No (used first, code poses as fallback); facepalm, shrug and laugh exist in no pack, so they
	# are code poses on every tier (one-shots ease in and out, laugh loops).
	"talk_ual": {"dur": 2.4, "loop": true, "src": [{"t": "ual1", "a": "Idle_Talking"}, {"t": "code", "a": "talk"}]},
	"fold_arms": {"dur": 3.0, "loop": true, "src": [{"t": "ual2", "a": "Idle_FoldArms"}, {"t": "code", "a": "arms_crossed"}]},
	"head_no": {"dur": 1.2, "src": [{"t": "ual2", "a": "Idle_No"}, {"t": "code", "a": "head_shake"}]},
	"facepalm": {"dur": 1.8, "src": [{"t": "code", "a": "facepalm"}]},
	"shrug": {"dur": 1.2, "src": [{"t": "code", "a": "shrug"}]},
	"laugh": {"dur": 1.0, "loop": true, "src": [{"t": "code", "a": "laugh"}]},
	# --- W6 stream C, seg_d5_boss (plan 2026-11-05-w6-fights): the Vovinam staff fight against Za Mẫn's katana. Code on
	# every tier: the staff and the katana are held props whose angle the timeline keys, so the contacts must not depend
	# on the tier. The staff's own angle (actor frame) comes from the timeline's hold track, not from these poses.
	"staff_thrust": {"dur": 0.6, "hit_u": 0.45, "src": [{"t": "code", "a": "staff_thrust", "hit": 0.45}]},
	"staff_sweep": {"dur": 0.9, "hit_u": 0.5, "src": [{"t": "code", "a": "staff_sweep", "hit": 0.5}]},
	"staff_swing": {"dur": 0.7, "hit_u": 0.5, "src": [{"t": "code", "a": "staff_swing", "hit": 0.5}]},
	"staff_run": {"dur": 0.5, "loop": true, "src": [{"t": "code", "a": "staff_run"}]},
	"katana_slash": {"dur": 0.9, "hit_u": 0.5, "src": [{"t": "code", "a": "katana_slash", "hit": 0.5}]},
	"blown_back": {"dur": 0.6, "loop": true, "hit_u": 0.0, "src": [{"t": "code", "a": "blown_back"}]},
	"staff_smash": {"dur": 0.6, "hit_u": 0.37, "src": [{"t": "code", "a": "chair_smash", "hit": 0.37}]},   # the overhead smash met high (on a raised block)
	# --- end W6 stream C, seg_d5_boss
	# --- W6 phase2 (plan 2026-11-05-w6-fights task 5, seg_d7_phase2; poses in the W6 phase2 block before code_pose, code
	# on every tier): a hopping overhand flashlight bonk, a matador's sidestep, a bull's paw and head-down charge, Lọ
	# cradling his antique urn and flinging it up in despair, the two-handed catch (the signature) and the jumping crown that
	# slams the caught urn down over a head, the cower under it, the rigid stand, the knuckle knock and the timber fall
	"bonk": {"dur": 0.7, "hit_u": 0.5, "air": [0.3, 0.68], "src": [{"t": "code", "a": "bonk", "hit": 0.5, "arc": 0.22}]},
	"ole": {"dur": 1.0, "src": [{"t": "code", "a": "ole"}]},
	"paw": {"dur": 0.6, "loop": true, "src": [{"t": "code", "a": "paw"}]},
	"ram": {"dur": 0.8, "hit_u": 0.85, "src": [{"t": "code", "a": "ram", "hit": 0.85}]},
	"cradle": {"dur": 1.6, "loop": true, "src": [{"t": "code", "a": "cradle"}]},
	"fling": {"dur": 0.9, "hit_u": 0.4, "src": [{"t": "code", "a": "fling", "hit": 0.4}]},
	"catch": {"dur": 0.8, "hit_u": 0.35, "src": [{"t": "code", "a": "catch", "hit": 0.35}]},
	"crown": {"dur": 0.8, "hit_u": 0.55, "air": [0.22, 0.72], "src": [{"t": "code", "a": "crown", "hit": 0.55, "arc": 0.22}]},
	"cower": {"dur": 1.2, "loop": true, "src": [{"t": "code", "a": "cower"}]},
	"rigid": {"dur": 0.5, "loop": true, "src": [{"t": "code", "a": "rigid"}]},
	"knock": {"dur": 0.7, "hit_u": 0.6, "src": [{"t": "code", "a": "knock", "hit": 0.6}]},
	"plank": {"dur": 0.75, "src": [{"t": "code", "a": "plank"}]},   # into "lie_flat" where he lies
	"sit_down": {"dur": 0.4, "src": [{"t": "code", "a": "sit_down"}]},   # into "slumped" where he stands
}

## Two-handed overhead smash (a chair or the soup pot held between both hands): wind up over the head, bring it down on
## the impact (hit 0.5), follow through, recover to a low guard.
const SMASH_KEYS: Array = [
	[0.0, {"shoulder_l": Vector3(1.0, 0.0, 0.12), "elbow_l": Vector3(1.2, 0.0, 0.0), "shoulder_r": Vector3(1.0, 0.0, -0.12),
		"elbow_r": Vector3(1.2, 0.0, 0.0), "torso": Vector3(0.0, 0.0, 0.0), "head": Vector3(0.0, 0.0, 0.0)}],
	[0.3, {"shoulder_l": Vector3(2.75, 0.0, 0.14), "elbow_l": Vector3(0.55, 0.0, 0.0), "shoulder_r": Vector3(2.75, 0.0, -0.14),
		"elbow_r": Vector3(0.55, 0.0, 0.0), "torso": Vector3(0.22, 0.0, 0.0), "head": Vector3(-0.2, 0.0, 0.0),
		"thigh_l": Vector3(0.15, 0.0, 0.06), "knee_l": Vector3(-0.2, 0.0, 0.0)}],
	[0.5, {"shoulder_l": Vector3(1.35, 0.0, 0.1), "elbow_l": Vector3(0.15, 0.0, 0.0), "shoulder_r": Vector3(1.35, 0.0, -0.1),
		"elbow_r": Vector3(0.15, 0.0, 0.0), "torso": Vector3(-0.45, 0.0, 0.0), "head": Vector3(0.15, 0.0, 0.0),
		"thigh_l": Vector3(0.35, 0.0, 0.06), "knee_l": Vector3(-0.45, 0.0, 0.0), "thigh_r": Vector3(-0.1, 0.0, -0.06),
		"knee_r": Vector3(-0.25, 0.0, 0.0)}],
	[0.75, {"shoulder_l": Vector3(0.75, 0.0, 0.1), "elbow_l": Vector3(0.3, 0.0, 0.0), "shoulder_r": Vector3(0.75, 0.0, -0.1),
		"elbow_r": Vector3(0.3, 0.0, 0.0), "torso": Vector3(-0.55, 0.0, 0.0), "head": Vector3(0.25, 0.0, 0.0),
		"thigh_l": Vector3(0.35, 0.0, 0.06), "knee_l": Vector3(-0.45, 0.0, 0.0), "thigh_r": Vector3(-0.1, 0.0, -0.06),
		"knee_r": Vector3(-0.25, 0.0, 0.0)}],
	[1.0, {"shoulder_l": Vector3(0.5, 0.0, 0.1), "elbow_l": Vector3(0.8, 0.0, 0.0), "shoulder_r": Vector3(0.5, 0.0, -0.1),
		"elbow_r": Vector3(0.8, 0.0, 0.0), "torso": Vector3(-0.12, 0.0, 0.0), "head": Vector3(0.05, 0.0, 0.0)}]]

## Fighting stance (code "stance" at u 0) as keyframe joints, shared by the brawling poses below.
const GUARD: Dictionary = {"thigh_l": Vector3(0.25, 0.0, 0.08), "knee_l": Vector3(-0.45, 0.0, 0.0),
	"thigh_r": Vector3(-0.1, 0.0, -0.08), "knee_r": Vector3(-0.35, 0.0, 0.0), "torso": Vector3(0.12, 0.35, 0.0),
	"head": Vector3(-0.08, -0.3, 0.0), "shoulder_l": Vector3(1.0, 0.0, -0.35), "elbow_l": Vector3(1.9, 0.0, 0.0),
	"shoulder_r": Vector3(0.8, 0.0, 0.4), "elbow_r": Vector3(2.1, 0.0, 0.0)}
## Both hands on the other man's collar / chest, feet staggered (grab, and the start of headbutt / hip_throw).
const GRAB: Dictionary = {"thigh_l": Vector3(0.4, 0.0, 0.08), "knee_l": Vector3(-0.6, 0.0, 0.0),
	"thigh_r": Vector3(-0.2, 0.0, -0.08), "knee_r": Vector3(-0.3, 0.0, 0.0), "torso": Vector3(-0.3, 0.0, 0.0),
	"head": Vector3(0.2, 0.0, 0.0), "shoulder_l": Vector3(1.3, 0.0, 0.2), "elbow_l": Vector3(0.9, 0.0, 0.0),
	"shoulder_r": Vector3(1.3, 0.0, -0.2), "elbow_r": Vector3(0.9, 0.0, 0.0), "body_y": -0.06}
## Brawling poses as keyframes [pose-u, joints] (smoothstep between neighbours, see _kpose).
const SHOVE_KEYS: Array = [
	[0.0, GUARD],
	[0.25, {"thigh_l": Vector3(0.3, 0.0, 0.08), "knee_l": Vector3(-0.5, 0.0, 0.0), "thigh_r": Vector3(-0.1, 0.0, -0.08),
		"knee_r": Vector3(-0.35, 0.0, 0.0), "torso": Vector3(0.05, 0.0, 0.0), "head": Vector3(0.0, 0.0, 0.0),
		"shoulder_l": Vector3(0.9, 0.0, 0.2), "elbow_l": Vector3(2.2, 0.0, 0.0), "shoulder_r": Vector3(0.9, 0.0, -0.2),
		"elbow_r": Vector3(2.2, 0.0, 0.0)}],
	[0.45, {"thigh_l": Vector3(0.65, 0.0, 0.08), "knee_l": Vector3(-0.75, 0.0, 0.0), "thigh_r": Vector3(-0.35, 0.0, -0.08),
		"knee_r": Vector3(-0.15, 0.0, 0.0), "torso": Vector3(-0.42, 0.0, 0.0), "head": Vector3(0.3, 0.0, 0.0),
		"shoulder_l": Vector3(1.65, 0.0, 0.12), "elbow_l": Vector3(0.15, 0.0, 0.0), "shoulder_r": Vector3(1.65, 0.0, -0.12),
		"elbow_r": Vector3(0.15, 0.0, 0.0), "body_y": -0.08}],
	[0.7, {"thigh_l": Vector3(0.6, 0.0, 0.08), "knee_l": Vector3(-0.7, 0.0, 0.0), "thigh_r": Vector3(-0.3, 0.0, -0.08),
		"knee_r": Vector3(-0.2, 0.0, 0.0), "torso": Vector3(-0.35, 0.0, 0.0), "head": Vector3(0.25, 0.0, 0.0),
		"shoulder_l": Vector3(1.55, 0.0, 0.05), "elbow_l": Vector3(0.4, 0.0, 0.0), "shoulder_r": Vector3(1.55, 0.0, -0.05),
		"elbow_r": Vector3(0.4, 0.0, 0.0), "body_y": -0.07}],
	[1.0, GUARD],
]
## A two-handed shove at head height (the crane hook's block, seg_d3_boss): hands up by the face, then arms out and up.
const SHOVE_HIGH_KEYS: Array = [
	[0.0, GUARD],
	[0.25, {"thigh_l": Vector3(0.3, 0.0, 0.08), "knee_l": Vector3(-0.5, 0.0, 0.0), "thigh_r": Vector3(-0.1, 0.0, -0.08),
		"knee_r": Vector3(-0.35, 0.0, 0.0), "torso": Vector3(0.08, 0.0, 0.0), "head": Vector3(-0.05, 0.0, 0.0),
		"shoulder_l": Vector3(1.5, 0.0, 0.25), "elbow_l": Vector3(1.9, 0.0, 0.0), "shoulder_r": Vector3(1.5, 0.0, -0.25),
		"elbow_r": Vector3(1.9, 0.0, 0.0)}],
	[0.45, {"thigh_l": Vector3(0.6, 0.0, 0.08), "knee_l": Vector3(-0.7, 0.0, 0.0), "thigh_r": Vector3(-0.3, 0.0, -0.08),
		"knee_r": Vector3(-0.15, 0.0, 0.0), "torso": Vector3(-0.18, 0.0, 0.0), "head": Vector3(0.12, 0.0, 0.0),
		"shoulder_l": Vector3(2.05, 0.0, 0.12), "elbow_l": Vector3(0.2, 0.0, 0.0), "shoulder_r": Vector3(2.05, 0.0, -0.12),
		"elbow_r": Vector3(0.2, 0.0, 0.0), "body_y": -0.03}],
	[0.7, {"thigh_l": Vector3(0.55, 0.0, 0.08), "knee_l": Vector3(-0.65, 0.0, 0.0), "thigh_r": Vector3(-0.28, 0.0, -0.08),
		"knee_r": Vector3(-0.2, 0.0, 0.0), "torso": Vector3(-0.14, 0.0, 0.0), "head": Vector3(0.1, 0.0, 0.0),
		"shoulder_l": Vector3(1.95, 0.0, 0.06), "elbow_l": Vector3(0.4, 0.0, 0.0), "shoulder_r": Vector3(1.95, 0.0, -0.06),
		"elbow_r": Vector3(0.4, 0.0, 0.0), "body_y": -0.03}],
	[1.0, GUARD],
]
const HEADBUTT_KEYS: Array = [
	[0.0, {"thigh_l": Vector3(0.3, 0.0, 0.08), "knee_l": Vector3(-0.5, 0.0, 0.0), "thigh_r": Vector3(-0.1, 0.0, -0.08),
		"knee_r": Vector3(-0.3, 0.0, 0.0), "torso": Vector3(-0.1, 0.0, 0.0), "head": Vector3(0.0, 0.0, 0.0),
		"shoulder_l": Vector3(0.5, 0.0, -0.25), "elbow_l": Vector3(0.9, 0.0, 0.0), "shoulder_r": Vector3(0.5, 0.0, 0.25),
		"elbow_r": Vector3(0.9, 0.0, 0.0), "body_y": -0.03}],
	[0.35, {"thigh_l": Vector3(0.35, 0.0, 0.08), "knee_l": Vector3(-0.55, 0.0, 0.0), "thigh_r": Vector3(-0.15, 0.0, -0.08),
		"knee_r": Vector3(-0.3, 0.0, 0.0), "torso": Vector3(0.15, 0.0, 0.0), "head": Vector3(0.35, 0.0, 0.0),
		"shoulder_l": Vector3(0.45, 0.0, -0.25), "elbow_l": Vector3(0.9, 0.0, 0.0), "shoulder_r": Vector3(0.45, 0.0, 0.25),
		"elbow_r": Vector3(0.9, 0.0, 0.0), "body_y": -0.05}],
	[0.5, {"thigh_l": Vector3(0.6, 0.0, 0.08), "knee_l": Vector3(-0.7, 0.0, 0.0), "thigh_r": Vector3(-0.3, 0.0, -0.08),
		"knee_r": Vector3(-0.2, 0.0, 0.0), "torso": Vector3(-0.3, 0.0, 0.0), "head": Vector3(-0.15, 0.0, 0.0),
		"shoulder_l": Vector3(0.45, 0.0, -0.25), "elbow_l": Vector3(0.9, 0.0, 0.0), "shoulder_r": Vector3(0.45, 0.0, 0.25),
		"elbow_r": Vector3(0.9, 0.0, 0.0), "body_y": -0.08}],
	[1.0, {"thigh_l": Vector3(0.3, 0.0, 0.08), "knee_l": Vector3(-0.5, 0.0, 0.0), "thigh_r": Vector3(-0.1, 0.0, -0.08),
		"knee_r": Vector3(-0.3, 0.0, 0.0), "torso": Vector3(-0.15, 0.0, 0.0), "head": Vector3(0.0, 0.0, 0.0),
		"shoulder_l": Vector3(0.9, 0.0, -0.3), "elbow_l": Vector3(1.6, 0.0, 0.0), "shoulder_r": Vector3(0.9, 0.0, 0.3),
		"elbow_r": Vector3(1.6, 0.0, 0.0), "body_y": -0.03}],
]
## Right hand up to the other man's head (pull his helmet off), then down to the side, cocked for a swing.
const YANK_KEYS: Array = [
	[0.0, GUARD],
	[0.45, {"thigh_l": Vector3(0.45, 0.0, 0.08), "knee_l": Vector3(-0.6, 0.0, 0.0), "thigh_r": Vector3(-0.2, 0.0, -0.08),
		"knee_r": Vector3(-0.25, 0.0, 0.0), "torso": Vector3(-0.2, 0.0, 0.0), "head": Vector3(0.15, 0.0, 0.0),
		"shoulder_l": Vector3(1.0, 0.0, -0.35), "elbow_l": Vector3(1.9, 0.0, 0.0), "shoulder_r": Vector3(1.75, 0.0, -0.15),
		"elbow_r": Vector3(0.1, 0.0, 0.0), "body_y": -0.05}],
	[1.0, {"thigh_l": Vector3(0.3, 0.0, 0.08), "knee_l": Vector3(-0.5, 0.0, 0.0), "thigh_r": Vector3(-0.1, 0.0, -0.08),
		"knee_r": Vector3(-0.35, 0.0, 0.0), "torso": Vector3(-0.05, 0.45, 0.0), "head": Vector3(0.08, -0.4, 0.0),
		"shoulder_l": Vector3(1.0, 0.0, -0.35), "elbow_l": Vector3(1.9, 0.0, 0.0), "shoulder_r": Vector3(0.6, 0.0, 0.45),
		"elbow_r": Vector3(1.3, 0.0, 0.0), "body_y": -0.03}],
]
## Grab, turn in and drop the hips under him (impact = the grab), then haul him over the hip.
const HIP_THROW_KEYS: Array = [
	[0.0, GRAB],
	[0.25, {"thigh_l": Vector3(0.35, 0.0, 0.08), "knee_l": Vector3(-0.75, 0.0, 0.0), "thigh_r": Vector3(0.1, 0.0, -0.08),
		"knee_r": Vector3(-0.6, 0.0, 0.0), "torso": Vector3(-0.35, 0.5, 0.0), "head": Vector3(0.1, -0.2, 0.0),
		"shoulder_l": Vector3(1.3, 0.0, 0.2), "elbow_l": Vector3(0.8, 0.0, 0.0), "shoulder_r": Vector3(1.3, 0.0, -0.2),
		"elbow_r": Vector3(0.8, 0.0, 0.0), "body_y": -0.08}],
	[0.6, {"thigh_l": Vector3(0.4, 0.0, 0.08), "knee_l": Vector3(-0.8, 0.0, 0.0), "thigh_r": Vector3(0.05, 0.0, -0.08),
		"knee_r": Vector3(-0.5, 0.0, 0.0), "torso": Vector3(-0.95, 0.9, 0.0), "head": Vector3(-0.3, -0.3, 0.0),
		"shoulder_l": Vector3(0.8, 0.0, 0.6), "elbow_l": Vector3(0.9, 0.0, 0.0), "shoulder_r": Vector3(0.5, 0.0, -0.7),
		"elbow_r": Vector3(0.6, 0.0, 0.0), "body_y": -0.09}],
	[1.0, {"thigh_l": Vector3(0.4, 0.0, 0.08), "knee_l": Vector3(-0.65, 0.0, 0.0), "thigh_r": Vector3(0.0, 0.0, -0.08),
		"knee_r": Vector3(-0.35, 0.0, 0.0), "torso": Vector3(-0.4, 0.3, 0.0), "head": Vector3(0.1, -0.1, 0.0),
		"shoulder_l": Vector3(0.5, 0.0, -0.3), "elbow_l": Vector3(0.8, 0.0, 0.0), "shoulder_r": Vector3(0.5, 0.0, 0.3),
		"elbow_r": Vector3(0.8, 0.0, 0.0), "body_y": -0.08}],
]
## Low crouch, then a spear tackle: shoulder into his midriff, arms wrapping (impact), into the drive.
const TACKLE_LUNGE: Dictionary = {"thigh_l": Vector3(1.0, 0.0, 0.08), "knee_l": Vector3(-1.2, 0.0, 0.0),
	"thigh_r": Vector3(-0.7, 0.0, -0.08), "knee_r": Vector3(-0.25, 0.0, 0.0), "torso": Vector3(-0.95, 0.0, 0.0),
	"head": Vector3(0.6, 0.0, 0.0), "shoulder_l": Vector3(1.2, 0.0, -0.45), "elbow_l": Vector3(1.3, 0.0, 0.0),
	"shoulder_r": Vector3(1.2, 0.0, 0.45), "elbow_r": Vector3(1.3, 0.0, 0.0), "body_y": -0.25}
const TACKLE_KEYS: Array = [
	[0.0, {"thigh_l": Vector3(0.7, 0.0, 0.08), "knee_l": Vector3(-1.1, 0.0, 0.0), "thigh_r": Vector3(0.6, 0.0, -0.08),
		"knee_r": Vector3(-1.0, 0.0, 0.0), "torso": Vector3(-0.5, 0.0, 0.0), "head": Vector3(0.3, 0.0, 0.0),
		"shoulder_l": Vector3(0.9, 0.0, -0.2), "elbow_l": Vector3(1.4, 0.0, 0.0), "shoulder_r": Vector3(0.9, 0.0, 0.2),
		"elbow_r": Vector3(1.4, 0.0, 0.0), "body_y": -0.14}],
	[0.6, TACKLE_LUNGE],
	[1.0, TACKLE_LUNGE],
]
## Squat and snatch something off the ground with the right hand (impact = the hand on it), back up holding it cocked.
const PICKUP_KEYS: Array = [
	[0.0, GUARD],
	[0.5, {"thigh_l": Vector3(1.4, 0.0, 0.1), "knee_l": Vector3(-2.0, 0.0, 0.0), "thigh_r": Vector3(1.2, 0.0, -0.1),
		"knee_r": Vector3(-1.9, 0.0, 0.0), "torso": Vector3(-1.1, 0.0, 0.0), "head": Vector3(0.4, 0.0, 0.0),
		"shoulder_l": Vector3(0.6, 0.0, -0.3), "elbow_l": Vector3(0.9, 0.0, 0.0), "shoulder_r": Vector3(0.9, 0.0, 0.1),
		"elbow_r": Vector3(0.1, 0.0, 0.0), "body_y": -0.41}],
	[1.0, {"thigh_l": Vector3(0.3, 0.0, 0.08), "knee_l": Vector3(-0.5, 0.0, 0.0), "thigh_r": Vector3(-0.1, 0.0, -0.08),
		"knee_r": Vector3(-0.35, 0.0, 0.0), "torso": Vector3(-0.05, 0.45, 0.0), "head": Vector3(0.08, -0.4, 0.0),
		"shoulder_l": Vector3(1.0, 0.0, -0.35), "elbow_l": Vector3(1.9, 0.0, 0.0), "shoulder_r": Vector3(0.6, 0.0, 0.45),
		"elbow_r": Vector3(1.3, 0.0, 0.0), "body_y": -0.03}],
]
## Head tilt right - crack - tilt left - crack, right hand at the jaw (impact = the first crack).
const NECK_CRACK_KEYS: Array = [
	[0.0, {"shoulder_l": Vector3(0.1, 0.0, -0.12), "elbow_l": Vector3(0.25, 0.0, 0.0), "shoulder_r": Vector3(0.1, 0.0, 0.12),
		"elbow_r": Vector3(0.25, 0.0, 0.0), "head": Vector3(0.0, 0.0, 0.0), "torso": Vector3(-0.03, 0.0, 0.0)}],
	[0.3, {"shoulder_l": Vector3(0.1, 0.0, -0.12), "elbow_l": Vector3(0.25, 0.0, 0.0), "shoulder_r": Vector3(1.5, 0.0, -0.5),
		"elbow_r": Vector3(2.3, 0.0, 0.0), "head": Vector3(-0.05, 0.0, 0.42), "torso": Vector3(-0.03, 0.0, 0.0)}],
	[0.45, {"shoulder_l": Vector3(0.1, 0.0, -0.12), "elbow_l": Vector3(0.25, 0.0, 0.0), "shoulder_r": Vector3(1.5, 0.0, -0.5),
		"elbow_r": Vector3(2.3, 0.0, 0.0), "head": Vector3(-0.05, 0.0, 0.6), "torso": Vector3(-0.03, 0.0, 0.0)}],
	[0.68, {"shoulder_l": Vector3(0.1, 0.0, -0.12), "elbow_l": Vector3(0.25, 0.0, 0.0), "shoulder_r": Vector3(1.5, 0.0, -0.5),
		"elbow_r": Vector3(2.3, 0.0, 0.0), "head": Vector3(-0.05, 0.0, -0.42), "torso": Vector3(-0.03, 0.0, 0.0)}],
	[0.78, {"shoulder_l": Vector3(0.1, 0.0, -0.12), "elbow_l": Vector3(0.25, 0.0, 0.0), "shoulder_r": Vector3(1.3, 0.0, -0.45),
		"elbow_r": Vector3(2.2, 0.0, 0.0), "head": Vector3(-0.05, 0.0, -0.6), "torso": Vector3(-0.03, 0.0, 0.0)}],
	[1.0, {"shoulder_l": Vector3(0.1, 0.0, -0.12), "elbow_l": Vector3(0.25, 0.0, 0.0), "shoulder_r": Vector3(0.1, 0.0, 0.12),
		"elbow_r": Vector3(0.25, 0.0, 0.0), "head": Vector3(0.05, 0.0, 0.0), "torso": Vector3(-0.03, 0.0, 0.0)}],
]


static func has_move(move_name: String) -> bool:
	return MOVES.has(move_name)


static func is_strike(move_name: String) -> bool:
	return MOVES.has(move_name) and float((MOVES[move_name] as Dictionary).get("hit_u", -1.0)) >= 0.0


static func tier_index(t: String) -> int:
	match t:
		"mixamo":
			return 0
		"ual1", "ual2":
			return 1
		"native":
			return 2
	return 3


static func _entry_ok(e: Dictionary, bd: Dictionary) -> bool:
	match String(e["t"]):
		"code":
			return true
		"native":
			return bd.has("native") and (bd["native"]["anims"] as Dictionary).has(String(e["a"]))
	return CineRetarget.has_anim(String(e["t"]), String(e["a"]))


## Time scale of this rig's native clips against the men/* rigs the native windows were authored on (cached in bd).
static func native_scale(bd: Dictionary) -> float:
	if bd.has("native_scale"):
		return bd["native_scale"]
	var sc: float = 1.0
	if bd.has("native") and (bd["native"]["anims"] as Dictionary).has(NATIVE_REF_CLIP):
		var l: float = CineRetarget.anim_length("native", NATIVE_REF_CLIP, bd)
		if l > 0.0 and absf(l / NATIVE_REF_LEN - 1.0) > 0.01:
			sc = l / NATIVE_REF_LEN
	bd["native_scale"] = sc
	return sc


## The entry a move plays for this skeleton (bd = CineRetarget.bind()), flattened with the move's fields.
static func resolve(move_name: String, bd: Dictionary) -> Dictionary:
	if not MOVES.has(move_name):
		return {}
	var m: Dictionary = MOVES[move_name]
	var pick: Dictionary = {}
	var last_ok: Dictionary = {}
	for e: Dictionary in m["src"]:
		if not _entry_ok(e, bd):
			continue
		last_ok = e
		if pick.is_empty() and tier_index(String(e["t"])) >= max_tier:
			pick = e
	if pick.is_empty():
		pick = last_ok
	if pick.is_empty():
		return {}
	var r: Dictionary = {"move": move_name, "t": String(pick["t"]), "a": String(pick["a"]),
		"tier": TIERS[tier_index(String(pick["t"]))],
		"from": float(pick.get("from", 0.0)), "hit": float(pick.get("hit", -1.0)), "to": float(pick.get("to", -1.0)),
		"arc": float(pick.get("arc", 0.0)), "spin": pick.get("spin", Vector3.ZERO), "add": String(pick.get("add", "")),
		"yaw": float(pick.get("yaw", 0.0)), "hold_spin": bool(pick.get("hold_spin", false)),
		"ref": float(pick.get("ref", pick.get("from", 0.0))),
		"dur": float(m["dur"]), "hit_u": float(m.get("hit_u", -1.0)), "loop": bool(m.get("loop", false)),
		"air": m.get("air", []), "root_y": String(m.get("root_y", "keep"))}
	if r["t"] == "code":
		r["from"] = 0.0
		r["to"] = 1.0
	if r["t"] == "native":
		var sc: float = native_scale(bd)
		r["from"] = float(r["from"]) * sc
		if float(r["hit"]) >= 0.0:
			r["hit"] = float(r["hit"]) * sc
		if float(r["to"]) >= 0.0:
			r["to"] = float(r["to"]) * sc
	if r["t"] != "code" and float(r["to"]) < 0.0:
		r["to"] = CineRetarget.anim_length(String(r["t"]), String(r["a"]), bd)
	return r


## Clip seconds for story offset x (story seconds since the move started) of a resolved move played over dur story seconds.
## Strikes map [from, hit] onto [0, hit_u·dur] and [hit, to] onto [hit_u·dur, dur]; loops play at natural speed inside
## [from, to]; from > to plays backwards.
static func clip_time(res: Dictionary, x: float, dur: float, loop: bool) -> float:
	var a: float = res["from"]
	var b: float = res["to"]
	if loop:
		var span: float = absf(b - a)
		var dir: float = 1.0 if b >= a else -1.0
		return a + dir * (fposmod(x, span) if span > 0.0 else 0.0)
	var u: float = clampf(x / dur, 0.0, 1.0) if dur > 0.0 else 1.0
	var h: float = res["hit"]
	var hu: float = res["hit_u"]
	if h >= 0.0 and hu > 0.0 and hu < 1.0:
		if u <= hu:
			return lerpf(a, h, u / hu)
		return lerpf(h, b, (u - hu) / (1.0 - hu))
	return lerpf(a, b, u)


## Pose-u of a resolved move's additive layer at move progress u: [0, hit_u] -> [0, ADD_HIT], [hit_u, 1] -> [ADD_HIT, 1].
static func add_u(res: Dictionary, u: float) -> float:
	var hu: float = res["hit_u"]
	if hu <= 0.0 or hu >= 1.0:
		return clampf(u, 0.0, 1.0)
	return clip_time({"from": 0.0, "hit": ADD_HIT, "to": 1.0, "hit_u": hu}, u, 1.0, false)


## Keyframed code pose: keys = [[pose-u, {joint: Vector3 | float}], ...] ascending from 0, smoothstep between neighbours; a
## joint missing from a key counts as zero there.
static func _kpose(keys: Array, u: float) -> Dictionary:
	var x: float = clampf(u, 0.0, 1.0)
	var i: int = 1
	while i < keys.size() - 1 and x > float(keys[i][0]):
		i += 1
	var a: Array = keys[i - 1]
	var b: Array = keys[i]
	var t: float = _sm((x - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001))
	var da: Dictionary = a[1]
	var db: Dictionary = b[1]
	var out: Dictionary = {}
	for k: String in da.keys() + db.keys():
		if out.has(k):
			continue
		var va: Variant = da.get(k, Vector3.ZERO if db.get(k) is Vector3 else 0.0)
		var vb: Variant = db.get(k, Vector3.ZERO if da.get(k) is Vector3 else 0.0)
		out[k] = (va as Vector3).lerp(vb, t) if va is Vector3 else lerpf(float(va), float(vb), t)
	return out


static func _sm(u: float) -> float:
	var x: float = clampf(u, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## Pivot drop (m) that keeps the feet near the ground while the body pitches back by p rad about the hip-height pivot.
static func _lay_drop(p: float) -> float:
	return maxf(PIVOT_Y * cos(p), LIE_PIVOT_Y) - PIVOT_Y


## Get-up keyframes (u 0 lying = lie_back, 0.4 sitting, 0.7 squatting, 1 standing), smoothstep between them. Leg angles
## keep the ankles near the floor: with the body pitched back by p, a thigh flexed by f points f + p from straight down,
## the shin f + p + knee; ankle height = pivot - 0.45 (cos(thigh) + cos(shin)) (Task 7, checked numerically per frame).
## Pose-u of getup's sitting key (slumped / get_up_sit start there).
const GETUP_SIT_U: float = 0.4
const GETUP_KEYS: Array = [
	[0.0, PI * 0.5, LIE_PIVOT_Y, 0.35, -0.6, 0.05, -0.1, 0.3, 1.0, 0.4],
	[0.4, 0.3, 0.27, 1.7, -1.0, 1.7, -1.0, -0.5, 0.35, 0.2],
	[0.7, -0.3, 0.63, 1.7, -1.7, 1.7, -1.7, 0.9, 0.2, 0.6],
	[0.85, -0.12, 0.84, 0.8, -0.9, 0.8, -0.9, 0.4, 0.1, 0.3],
	[1.0, 0.0, PIVOT_Y, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
]


static func _getup_keys(u: float) -> Array:
	var x: float = clampf(u, 0.0, 1.0)
	for i: int in range(1, GETUP_KEYS.size()):
		var b: Array = GETUP_KEYS[i]
		if x <= float(b[0]) or i == GETUP_KEYS.size() - 1:
			var a: Array = GETUP_KEYS[i - 1]
			var t: float = _sm((x - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001))
			var out: Array = []
			for k: int in range(1, a.size()):
				out.append(lerpf(float(a[k]), float(b[k]), t))
			return out
	return []


# --- W6 stream C, seg_d5_boss: staff keyframes (both hands on the staff, held "mid" between them)
## The staff guard (code "staff_guard" at phase 0).
const STAFF_SG: Dictionary = {"shoulder_l": Vector3(0.95, 0.0, 0.3), "elbow_l": Vector3(1.0, 0.0, 0.0),
	"shoulder_r": Vector3(0.75, 0.0, -0.05), "elbow_r": Vector3(1.35, 0.0, 0.0), "torso": Vector3(0.1, 0.25, 0.0),
	"head": Vector3(-0.05, -0.25, 0.0), "thigh_l": Vector3(0.25, 0.0, 0.08), "knee_l": Vector3(-0.4, 0.0, 0.0),
	"thigh_r": Vector3(-0.1, 0.0, -0.08), "knee_r": Vector3(-0.3, 0.0, 0.0)}
## A two-handed thrust: the hands drawn back, then driven forward at chest height with a lunge (hit 0.45).
const STAFF_THRUST_KEYS: Array = [
	[0.0, STAFF_SG],
	[0.25, {"shoulder_l": Vector3(0.75, 0.0, 0.3), "elbow_l": Vector3(1.6, 0.0, 0.0), "shoulder_r": Vector3(0.6, 0.0, -0.05),
		"elbow_r": Vector3(1.8, 0.0, 0.0), "torso": Vector3(0.15, 0.3, 0.0), "head": Vector3(-0.08, -0.3, 0.0),
		"thigh_l": Vector3(0.25, 0.0, 0.08), "knee_l": Vector3(-0.4, 0.0, 0.0), "thigh_r": Vector3(-0.1, 0.0, -0.08),
		"knee_r": Vector3(-0.3, 0.0, 0.0)}],
	[0.45, {"shoulder_l": Vector3(1.35, 0.0, 0.12), "elbow_l": Vector3(0.15, 0.0, 0.0), "shoulder_r": Vector3(1.3, 0.0, -0.05),
		"elbow_r": Vector3(0.35, 0.0, 0.0), "torso": Vector3(-0.3, 0.05, 0.0), "head": Vector3(0.25, 0.0, 0.0),
		"thigh_l": Vector3(0.65, 0.0, 0.08), "knee_l": Vector3(-0.75, 0.0, 0.0), "thigh_r": Vector3(-0.35, 0.0, -0.08),
		"knee_r": Vector3(-0.15, 0.0, 0.0), "body_y": -0.08}],
	[0.7, {"shoulder_l": Vector3(1.3, 0.0, 0.14), "elbow_l": Vector3(0.35, 0.0, 0.0), "shoulder_r": Vector3(1.25, 0.0, -0.05),
		"elbow_r": Vector3(0.5, 0.0, 0.0), "torso": Vector3(-0.25, 0.05, 0.0), "head": Vector3(0.2, 0.0, 0.0),
		"thigh_l": Vector3(0.6, 0.0, 0.08), "knee_l": Vector3(-0.7, 0.0, 0.0), "thigh_r": Vector3(-0.3, 0.0, -0.08),
		"knee_r": Vector3(-0.2, 0.0, 0.0), "body_y": -0.07}],
	[1.0, STAFF_SG],
]
## Deep crouch for the low sweep (the timeline turns the body through it and pitches the staff down to the shins).
const STAFF_CROUCH: Dictionary = {"body_y": -0.33, "thigh_l": Vector3(1.3, 0.0, 0.15), "knee_l": Vector3(-1.6, 0.0, 0.0),
	"thigh_r": Vector3(1.3, 0.0, -0.15), "knee_r": Vector3(-1.6, 0.0, 0.0), "torso": Vector3(-0.45, 0.0, 0.0),
	"head": Vector3(0.45, 0.0, 0.0), "shoulder_l": Vector3(0.8, 0.0, 0.2), "elbow_l": Vector3(0.35, 0.0, 0.0),
	"shoulder_r": Vector3(0.7, 0.0, -0.1), "elbow_r": Vector3(0.5, 0.0, 0.0)}
## Staff held across at head height for the spinning strike (the timeline spins the body through it).
const STAFF_HIGH: Dictionary = {"shoulder_l": Vector3(1.75, 0.0, 0.15), "elbow_l": Vector3(0.7, 0.0, 0.0),
	"shoulder_r": Vector3(1.75, 0.0, -0.15), "elbow_r": Vector3(0.7, 0.0, 0.0), "torso": Vector3(-0.1, 0.0, 0.0),
	"head": Vector3(0.05, 0.0, 0.0), "thigh_l": Vector3(0.35, 0.0, 0.08), "knee_l": Vector3(-0.5, 0.0, 0.0),
	"thigh_r": Vector3(-0.2, 0.0, -0.08), "knee_r": Vector3(-0.2, 0.0, 0.0)}
## The low sweep: down into the deep crouch, held through the sweep, back up to the guard.
const STAFF_SWEEP_KEYS: Array = [[0.0, STAFF_SG], [0.3, STAFF_CROUCH], [0.7, STAFF_CROUCH], [1.0, STAFF_SG]]
## The spinning strike: the staff raised across to head height, held through it, back down.
const STAFF_SWING_KEYS: Array = [[0.0, STAFF_SG], [0.3, STAFF_HIGH], [0.7, STAFF_HIGH], [1.0, STAFF_SG]]
## Za Mẫn's horizontal katana cut, both hands on the hilt, arms out in front at shoulder height (the timeline turns his
## body through it); he stays extended, the blade stuck in a rack, until the next move.
const KATANA_SLASH_KEYS: Array = [
	[0.0, {"shoulder_l": Vector3(0.9, 0.0, 0.25), "elbow_l": Vector3(1.0, 0.0, 0.0), "shoulder_r": Vector3(0.9, 0.0, -0.25),
		"elbow_r": Vector3(1.0, 0.0, 0.0), "torso": Vector3(0.05, 0.0, 0.0), "thigh_l": Vector3(0.25, 0.0, 0.08),
		"knee_l": Vector3(-0.4, 0.0, 0.0), "thigh_r": Vector3(-0.1, 0.0, -0.08), "knee_r": Vector3(-0.3, 0.0, 0.0)}],
	[0.3, {"shoulder_l": Vector3(1.25, 0.0, 0.3), "elbow_l": Vector3(0.7, 0.0, 0.0), "shoulder_r": Vector3(1.25, 0.0, -0.3),
		"elbow_r": Vector3(0.7, 0.0, 0.0), "torso": Vector3(0.1, 0.0, 0.0), "thigh_l": Vector3(0.3, 0.0, 0.1),
		"knee_l": Vector3(-0.45, 0.0, 0.0), "thigh_r": Vector3(-0.15, 0.0, -0.1), "knee_r": Vector3(-0.3, 0.0, 0.0)}],
	[0.5, {"shoulder_l": Vector3(1.5, 0.0, 0.3), "elbow_l": Vector3(0.1, 0.0, 0.0), "shoulder_r": Vector3(1.5, 0.0, -0.3),
		"elbow_r": Vector3(0.1, 0.0, 0.0), "torso": Vector3(-0.15, 0.0, 0.0), "head": Vector3(0.1, 0.0, 0.0),
		"thigh_l": Vector3(0.5, 0.0, 0.1), "knee_l": Vector3(-0.6, 0.0, 0.0), "thigh_r": Vector3(-0.25, 0.0, -0.1),
		"knee_r": Vector3(-0.2, 0.0, 0.0), "body_y": -0.05}],
	[1.0, {"shoulder_l": Vector3(1.45, 0.0, 0.3), "elbow_l": Vector3(0.15, 0.0, 0.0), "shoulder_r": Vector3(1.45, 0.0, -0.3),
		"elbow_r": Vector3(0.15, 0.0, 0.0), "torso": Vector3(-0.1, 0.0, 0.0), "head": Vector3(0.05, 0.0, 0.0),
		"thigh_l": Vector3(0.45, 0.0, 0.1), "knee_l": Vector3(-0.55, 0.0, 0.0), "thigh_r": Vector3(-0.2, 0.0, -0.1),
		"knee_r": Vector3(-0.2, 0.0, 0.0), "body_y": -0.04}],
]
# --- end W6 stream C, seg_d5_boss keyframes
# --- W6 phase2 (plan 2026-11-05-w6-fights task 5): seg_d7_phase2's code poses (code_pose hands these names to _w6p2_pose)
const W6P2_POSES: Dictionary = {"bonk": true, "ole": true, "paw": true, "ram": true, "cradle": true, "fling": true,
	"catch": true, "crown": true, "cower": true, "rigid": true, "knock": true, "plank": true, "sit_down": true}
## The knock: the right shoulder raised this far (rad), the elbow bent this far, and each knock opens it this much.
const KNOCK_SHOULDER: float = 1.7
const KNOCK_ELBOW: float = 1.5
const KNOCK_TAP: float = 0.35
## The ram's dive at the hit: [torso bend (rad), whole-body pitch (rad, - = forward), body drop (m)].
const RAM_DIVE: Array[float] = [-0.35, -0.7, 0.1]
## Both hands round a jar held in front of the belly (cradle, the start of fling).
const CRADLE: Dictionary = {"shoulder_l": Vector3(0.7, 0.0, -0.08), "elbow_l": Vector3(1.3, 0.0, 0.0),
	"shoulder_r": Vector3(0.7, 0.0, 0.08), "elbow_r": Vector3(1.3, 0.0, 0.0), "torso": Vector3(0.08, 0.0, 0.0),
	"head": Vector3(-0.2, 0.0, 0.0)}
## Both hands round the caught urn at the chest (the end of catch, the start of crown).
const CARRY: Dictionary = {"shoulder_l": Vector3(0.95, 0.0, -0.12), "elbow_l": Vector3(1.3, 0.0, 0.0),
	"shoulder_r": Vector3(0.95, 0.0, 0.12), "elbow_r": Vector3(1.3, 0.0, 0.0), "torso": Vector3(0.06, 0.0, 0.0),
	"head": Vector3(-0.15, 0.0, 0.0), "thigh_l": Vector3(0.25, 0.0, 0.08), "knee_l": Vector3(-0.4, 0.0, 0.0),
	"thigh_r": Vector3(-0.05, 0.0, -0.08), "knee_r": Vector3(-0.3, 0.0, 0.0)}
## Overhand blow with the right hand (a flashlight held pointing forward-down): cocked behind the head, down onto the
## other man's forehead (hit 0.5), follow through, back to the guard.
const BONK_KEYS: Array = [
	[0.0, GUARD],
	[0.32, {"thigh_l": Vector3(0.2, 0.0, 0.08), "knee_l": Vector3(-0.4, 0.0, 0.0), "thigh_r": Vector3(-0.15, 0.0, -0.08),
		"knee_r": Vector3(-0.3, 0.0, 0.0), "torso": Vector3(0.18, -0.3, 0.0), "head": Vector3(-0.15, 0.3, 0.0),
		"shoulder_l": Vector3(1.1, 0.0, -0.3), "elbow_l": Vector3(1.7, 0.0, 0.0), "shoulder_r": Vector3(3.0, 0.0, 0.35),
		"elbow_r": Vector3(1.3, 0.0, 0.0)}],
	[0.5, {"thigh_l": Vector3(0.55, 0.0, 0.08), "knee_l": Vector3(-0.65, 0.0, 0.0), "thigh_r": Vector3(-0.3, 0.0, -0.08),
		"knee_r": Vector3(-0.2, 0.0, 0.0), "torso": Vector3(-0.12, 0.3, 0.0), "head": Vector3(0.1, -0.3, 0.0),
		"shoulder_l": Vector3(0.8, 0.0, -0.4), "elbow_l": Vector3(1.5, 0.0, 0.0), "shoulder_r": Vector3(2.95, 0.0, 0.1),
		"elbow_r": Vector3(0.2, 0.0, 0.0), "body_y": -0.05}],
	[0.72, {"thigh_l": Vector3(0.5, 0.0, 0.08), "knee_l": Vector3(-0.6, 0.0, 0.0), "thigh_r": Vector3(-0.28, 0.0, -0.08),
		"knee_r": Vector3(-0.22, 0.0, 0.0), "torso": Vector3(-0.35, 0.35, 0.0), "head": Vector3(0.2, -0.3, 0.0),
		"shoulder_l": Vector3(0.8, 0.0, -0.4), "elbow_l": Vector3(1.5, 0.0, 0.0), "shoulder_r": Vector3(1.4, 0.0, 0.1),
		"elbow_r": Vector3(0.3, 0.0, 0.0), "body_y": -0.05}],
	[1.0, GUARD],
]
## Both palms on the cheeks, elbows out, knees sagging (the end of fling).
const FLING_CHEEKS: Dictionary = {"shoulder_l": Vector3(1.05, 0.0, -0.3), "elbow_l": Vector3(2.4, 0.0, 0.0),
	"shoulder_r": Vector3(1.05, 0.0, 0.3), "elbow_r": Vector3(2.4, 0.0, 0.0), "torso": Vector3(0.12, 0.0, 0.0),
	"head": Vector3(-0.12, 0.0, 0.0), "thigh_l": Vector3(0.3, 0.0, 0.1), "knee_l": Vector3(-0.5, 0.0, 0.0),
	"thigh_r": Vector3(0.3, 0.0, -0.1), "knee_r": Vector3(-0.5, 0.0, 0.0), "body_y": -0.05}
## Lọ's despair: both hands flung up from the cradle (the jar he holds "mid" flies off the top, hit 0.4), then both
## palms to the cheeks.
const FLING_KEYS: Array = [
	[0.0, CRADLE],
	[0.4, {"shoulder_l": Vector3(2.5, 0.0, -0.15), "elbow_l": Vector3(0.35, 0.0, 0.0), "shoulder_r": Vector3(2.5, 0.0, 0.15),
		"elbow_r": Vector3(0.35, 0.0, 0.0), "torso": Vector3(0.18, 0.0, 0.0), "head": Vector3(-0.3, 0.0, 0.0),
		"thigh_l": Vector3(0.2, 0.0, 0.08), "knee_l": Vector3(-0.25, 0.0, 0.0), "thigh_r": Vector3(-0.1, 0.0, -0.08),
		"knee_r": Vector3(-0.15, 0.0, 0.0)}],
	[0.7, FLING_CHEEKS],
	[1.0, FLING_CHEEKS],
]
## The catch: both hands up and out to a flying jar (hit 0.35: the hands on it), the weight rocks the body back on bent
## knees, then the jar carried at the chest.
const CATCH_KEYS: Array = [
	[0.0, GUARD],
	[0.35, {"shoulder_l": Vector3(1.75, 0.0, -0.15), "elbow_l": Vector3(0.35, 0.0, 0.0), "shoulder_r": Vector3(1.75, 0.0, 0.15),
		"elbow_r": Vector3(0.35, 0.0, 0.0), "torso": Vector3(0.05, 0.0, 0.0), "head": Vector3(0.1, 0.0, 0.0),
		"thigh_l": Vector3(0.3, 0.0, 0.08), "knee_l": Vector3(-0.45, 0.0, 0.0), "thigh_r": Vector3(-0.1, 0.0, -0.08),
		"knee_r": Vector3(-0.3, 0.0, 0.0)}],
	[0.6, {"shoulder_l": Vector3(1.15, 0.0, -0.18), "elbow_l": Vector3(1.1, 0.0, 0.0), "shoulder_r": Vector3(1.15, 0.0, 0.18),
		"elbow_r": Vector3(1.1, 0.0, 0.0), "torso": Vector3(0.22, 0.0, 0.0), "head": Vector3(-0.1, 0.0, 0.0),
		"thigh_l": Vector3(0.45, 0.0, 0.08), "knee_l": Vector3(-0.75, 0.0, 0.0), "thigh_r": Vector3(0.1, 0.0, -0.08),
		"knee_r": Vector3(-0.65, 0.0, 0.0), "body_y": -0.08}],
	[1.0, CARRY],
]
## The jumping crown: crouch with the jar, spring up with it over the head, slam it down over the other man's head (hit
## 0.55, airborne: the move's "air" window), land with it pressed down on his shoulders, let go.
const CROWN_KEYS: Array = [
	[0.0, CARRY],
	[0.2, {"shoulder_l": Vector3(1.6, 0.0, -0.15), "elbow_l": Vector3(0.9, 0.0, 0.0), "shoulder_r": Vector3(1.6, 0.0, 0.15),
		"elbow_r": Vector3(0.9, 0.0, 0.0), "torso": Vector3(-0.25, 0.0, 0.0), "head": Vector3(0.3, 0.0, 0.0),
		"thigh_l": Vector3(0.7, 0.0, 0.08), "knee_l": Vector3(-1.2, 0.0, 0.0), "thigh_r": Vector3(0.5, 0.0, -0.08),
		"knee_r": Vector3(-1.0, 0.0, 0.0), "body_y": -0.15}],
	[0.45, {"shoulder_l": Vector3(2.6, 0.0, -0.18), "elbow_l": Vector3(0.4, 0.0, 0.0), "shoulder_r": Vector3(2.6, 0.0, 0.18),
		"elbow_r": Vector3(0.4, 0.0, 0.0), "torso": Vector3(0.05, 0.0, 0.0), "head": Vector3(-0.25, 0.0, 0.0),
		"thigh_l": Vector3(0.4, 0.0, 0.08), "knee_l": Vector3(-0.6, 0.0, 0.0), "thigh_r": Vector3(0.1, 0.0, -0.08),
		"knee_r": Vector3(-0.5, 0.0, 0.0)}],
	[0.55, {"shoulder_l": Vector3(2.2, 0.0, -0.18), "elbow_l": Vector3(0.3, 0.0, 0.0), "shoulder_r": Vector3(2.2, 0.0, 0.18),
		"elbow_r": Vector3(0.3, 0.0, 0.0), "torso": Vector3(-0.15, 0.0, 0.0), "head": Vector3(-0.3, 0.0, 0.0),
		"thigh_l": Vector3(0.45, 0.0, 0.08), "knee_l": Vector3(-0.7, 0.0, 0.0), "thigh_r": Vector3(0.15, 0.0, -0.08),
		"knee_r": Vector3(-0.6, 0.0, 0.0)}],
	[0.75, {"shoulder_l": Vector3(1.8, 0.0, -0.2), "elbow_l": Vector3(0.35, 0.0, 0.0), "shoulder_r": Vector3(1.8, 0.0, 0.2),
		"elbow_r": Vector3(0.35, 0.0, 0.0), "torso": Vector3(-0.3, 0.0, 0.0), "head": Vector3(-0.2, 0.0, 0.0),
		"thigh_l": Vector3(0.6, 0.0, 0.08), "knee_l": Vector3(-1.0, 0.0, 0.0), "thigh_r": Vector3(0.35, 0.0, -0.08),
		"knee_r": Vector3(-0.8, 0.0, 0.0), "body_y": -0.1}],
	[1.0, {"shoulder_l": Vector3(0.5, 0.0, -0.2), "elbow_l": Vector3(0.6, 0.0, 0.0), "shoulder_r": Vector3(0.5, 0.0, 0.2),
		"elbow_r": Vector3(0.6, 0.0, 0.0), "torso": Vector3(-0.05, 0.0, 0.0), "head": Vector3(0.0, 0.0, 0.0),
		"thigh_l": Vector3(0.25, 0.0, 0.08), "knee_l": Vector3(-0.4, 0.0, 0.0), "thigh_r": Vector3(-0.05, 0.0, -0.08),
		"knee_r": Vector3(-0.3, 0.0, 0.0)}],
]


static func _w6p2_pose(pose: String, u: float) -> Dictionary:
	match pose:
		"bonk":
			return _kpose(BONK_KEYS, u)
		"ole":        # the matador's sidestep: arched back and turned to the passing bull, both arms up and out over its
			# path like a cape; eases in and out
			var oa: float = _sm(clampf(u / 0.35, 0.0, 1.0)) * (1.0 - _sm(clampf((u - 0.7) / 0.3, 0.0, 1.0)))
			return {"torso": Vector3(0.22 * oa, -0.4 * oa, 0.0), "head": Vector3(-0.12 * oa, 0.3 * oa, 0.0),
				"shoulder_r": Vector3(0.1 + 2.3 * oa, 0.0, 0.12 + 0.5 * oa), "elbow_r": Vector3(0.25, 0.0, 0.0),
				"shoulder_l": Vector3(0.1 + 2.6 * oa, 0.0, -0.12 - 0.2 * oa), "elbow_l": Vector3(0.25 + 0.4 * oa, 0.0, 0.0),
				"thigh_l": Vector3(0.05, 0.0, 0.08), "knee_l": Vector3(-0.15, 0.0, 0.0),
				"thigh_r": Vector3(-0.1 * oa, 0.0, -0.08 - 0.12 * oa), "knee_r": Vector3(-0.1, 0.0, 0.0)}
		"paw":        # a bull before the charge: head down, the right foot scraping the floor back (loop phase u)
			var sc: float = sin(u * TAU)
			return {"torso": Vector3(-0.45, 0.0, 0.0), "head": Vector3(0.15, 0.0, 0.0),
				"shoulder_l": Vector3(-0.3, 0.0, -0.2), "elbow_l": Vector3(0.5, 0.0, 0.0), "shoulder_r": Vector3(-0.3, 0.0, 0.2),
				"elbow_r": Vector3(0.5, 0.0, 0.0), "thigh_l": Vector3(0.35, 0.0, 0.08), "knee_l": Vector3(-0.55, 0.0, 0.0),
				"thigh_r": Vector3(0.05 - 0.35 * sc, 0.0, -0.08), "knee_r": Vector3(-0.35 - 0.3 * maxf(sc, 0.0), 0.0, 0.0),
				"body_y": -0.06}
		"ram":        # a bull's charge: bent double, crown first, arms back, legs churning; the last stride a dive (the
			# whole body tipped forward, the feet off the floor) that puts the head into the target (hit 0.85); then
			# back onto his feet, staggered
			var rk: float = clampf(u / 0.85, 0.0, 1.0)
			var ph2: float = rk * TAU * 2.5
			var dv: float = _sm(clampf((u - 0.6) / 0.25, 0.0, 1.0))
			var rc: float = _sm(clampf((u - 0.85) / 0.15, 0.0, 1.0))
			var run: float = 1.0 - dv
			var sw: float = 0.45 * sin(ph2) * run
			var rm: Dictionary = {"torso": Vector3(lerpf(-0.75, RAM_DIVE[0], dv), 0.0, 0.0), "head": Vector3(lerpf(0.2, 0.35, dv), 0.0, 0.0),
				"shoulder_l": Vector3(lerpf(-0.5, -0.9, dv), 0.0, -0.2), "elbow_l": Vector3(lerpf(0.6, 0.2, dv), 0.0, 0.0),
				"shoulder_r": Vector3(lerpf(-0.5, -0.9, dv), 0.0, 0.2), "elbow_r": Vector3(lerpf(0.6, 0.2, dv), 0.0, 0.0),
				"thigh_l": Vector3(lerpf(0.4, -0.1, dv) + sw, 0.0, 0.08),
				"knee_l": Vector3(lerpf(-0.55, -0.25, dv) - 0.45 * maxf(cos(ph2), 0.0) * run, 0.0, 0.0),
				"thigh_r": Vector3(lerpf(0.4, -0.1, dv) - sw, 0.0, -0.08),
				"knee_r": Vector3(lerpf(-0.55, -0.25, dv) - 0.45 * maxf(-cos(ph2), 0.0) * run, 0.0, 0.0),
				"body_pitch": RAM_DIVE[1] * dv, "body_y": lerpf(-0.12, RAM_DIVE[2], dv)}
			if rc > 0.0:
				var up: Dictionary = {"torso": Vector3(-0.2, 0.0, 0.0), "head": Vector3(-0.1, 0.0, 0.0),
					"shoulder_l": Vector3(0.3, 0.0, -0.5), "elbow_l": Vector3(0.5, 0.0, 0.0),
					"shoulder_r": Vector3(0.3, 0.0, 0.5), "elbow_r": Vector3(0.5, 0.0, 0.0),
					"thigh_l": Vector3(0.1, 0.0, 0.08), "knee_l": Vector3(-0.2, 0.0, 0.0),
					"thigh_r": Vector3(0.1, 0.0, -0.08), "knee_r": Vector3(-0.2, 0.0, 0.0), "body_pitch": 0.0, "body_y": -0.03}
				for j: String in rm.keys():
					rm[j] = lerp(rm[j], up[j], rc)
			return rm
		"cradle":     # a jar held like a pet at the belly, rocked from side to side (loop phase u)
			var cr: Dictionary = CRADLE.duplicate()
			var sw: float = sin(u * TAU)
			cr["torso"] = (CRADLE["torso"] as Vector3) + Vector3(0.0, 0.12 * sw, 0.04 * sw)
			cr["head"] = (CRADLE["head"] as Vector3) + Vector3(0.0, -0.1 * sw, 0.06 * sw)
			return cr
		"fling":
			return _kpose(FLING_KEYS, u)
		"catch":
			return _kpose(CATCH_KEYS, u)
		"crown":
			return _kpose(CROWN_KEYS, u)
		"cower":      # ducked low, hunched, hugging himself (the arms crossed on the chest, clear of the head), trembling
			# (loop phase u)
			var tw: float = sin(u * TAU * 5.0) * 0.03
			return {"thigh_l": Vector3(0.75, 0.0, 0.1), "knee_l": Vector3(-1.2, 0.0, 0.0), "thigh_r": Vector3(0.65, 0.0, -0.1),
				"knee_r": Vector3(-1.1, 0.0, 0.0), "torso": Vector3(-0.4 + tw, 0.0, 0.0), "head": Vector3(0.2, tw, 0.0),
				"shoulder_l": Vector3(0.6 + tw, 0.0, 0.35), "elbow_l": Vector3(2.0, 0.0, 0.0),
				"shoulder_r": Vector3(0.6 - tw, 0.0, -0.35), "elbow_r": Vector3(2.0, 0.0, 0.0), "body_y": -0.17}
		"rigid":      # stiff as a post: heels together, arms clamped to the sides, a fine tremble (loop phase u)
			var rt: float = sin(u * TAU * 3.0) * 0.015
			return {"thigh_l": Vector3(0.0, 0.0, -0.02), "knee_l": Vector3(0.0, 0.0, 0.0), "thigh_r": Vector3(0.0, 0.0, 0.02),
				"knee_r": Vector3(0.0, 0.0, 0.0), "torso": Vector3(0.03 + rt, 0.0, 0.0), "head": Vector3(-0.05, rt, 0.0),
				"shoulder_l": Vector3(0.0, 0.0, 0.06), "elbow_l": Vector3(0.05, 0.0, 0.0),
				"shoulder_r": Vector3(0.0, 0.0, -0.06), "elbow_r": Vector3(0.05, 0.0, 0.0)}
		"knock":      # two knuckle knocks on something at head height, as on a door (the second one is the hit, 0.6)
			var ke: float = _sm(clampf(u / 0.25, 0.0, 1.0)) * (1.0 - _sm(clampf((u - 0.8) / 0.2, 0.0, 1.0)))
			var kk: float = 0.0
			for kt: float in [0.38, 0.6]:
				kk = maxf(kk, 1.0 - clampf(absf(u - kt) / 0.09, 0.0, 1.0))
			return {"shoulder_r": Vector3(0.1 + KNOCK_SHOULDER * ke, 0.0, 0.12 - 0.2 * ke),
				"elbow_r": Vector3(0.25 + (KNOCK_ELBOW - 0.25 - KNOCK_TAP * kk) * ke, 0.0, 0.0),
				"shoulder_l": Vector3(0.1, 0.0, -0.12), "elbow_l": Vector3(0.25 + 0.3 * ke, 0.0, 0.0),
				"torso": Vector3(-0.06 * ke, 0.12 * ke, 0.0), "head": Vector3(0.05 * ke, 0.0, 0.0),
				"thigh_l": Vector3(0.15 * ke, 0.0, 0.08), "knee_l": Vector3(-0.2 * ke, 0.0, 0.0)}
		"plank":      # toppling backwards stiff as a felled tree (slow, then fast) onto the back, arms still clamped
			var pu: float = clampf(u, 0.0, 1.0)
			var pp: float = PI * 0.5 * pu * pu
			var pk: Dictionary = code_pose("rigid", 0.0)
			pk["body_pitch"] = pp
			pk["body_y"] = _lay_drop(pp)
			return pk
		"sit_down":   # dazed, drops onto his backside: the get-up from the floor played backwards to its sitting key
			return code_pose("getup", lerpf(1.0, GETUP_SIT_U, clampf(u, 0.0, 1.0)))
	return {}


## Code poses {CharacterBuilder joint: Euler (character frame, rad)} applied with CharacterBuilder._apply_bone_pose on the
## neutral standing base; u = progress 0..1 through the move (loops: phase). flying_kick, spin_kick and scissor are the
## prototype's (git show ec72795:scripts/cine/CineBrawl.gd) – retune the leg angles on the neutral base by eye in Task 7.
## Whole-body keys (read by CineActor, ignored by _apply_bone_pose): "body_pitch" (rad, + = onto the back, about the
## hip-height pivot) and "body_y" (m, pivot offset) – the lying / get-up poses lay the whole body down with them.
static func code_pose(pose: String, u: float) -> Dictionary:
	if W6P2_POSES.has(pose):   # W6 phase2 block above
		return _w6p2_pose(pose, u)
	match pose:
		"stance":
			var br: float = sin(u * TAU) * 0.03
			return {"thigh_l": Vector3(0.25, 0.0, 0.08), "knee_l": Vector3(-0.45, 0.0, 0.0), "thigh_r": Vector3(-0.1, 0.0, -0.08),
				"knee_r": Vector3(-0.35, 0.0, 0.0), "torso": Vector3(0.12 + br, 0.35, 0.0), "head": Vector3(-0.08, -0.3, 0.0),
				"shoulder_l": Vector3(1.0, 0.0, -0.35), "elbow_l": Vector3(1.9, 0.0, 0.0),
				"shoulder_r": Vector3(0.8, 0.0, 0.4), "elbow_r": Vector3(2.1, 0.0, 0.0)}
		"taunt":
			var w: float = sin(u * TAU * 2.0)
			return {"torso": Vector3(-0.1, 0.0, 0.0), "shoulder_r": Vector3(1.4 + 0.3 * w, 0.0, 0.5), "elbow_r": Vector3(1.6, 0.0, 0.0),
				"shoulder_l": Vector3(0.9, 0.0, -0.4), "elbow_l": Vector3(2.0, 0.0, 0.0), "head": Vector3(-0.15, 0.0, 0.1 * w)}
		"flying_kick":   # LEFT foot strikes (as Mixamo Flying_Kick); mirror of the prototype pose (swap sides, negate y / z)
			var e: float = _sm(u / 0.86)
			return {"thigh_l": Vector3(lerpf(1.05, 1.62, e), 0.0, 0.08), "knee_l": Vector3(lerpf(-1.9, -0.02, e), 0.0, 0.0),
				"foot_l": Vector3(lerpf(0.4, -0.25, e), 0.0, 0.0), "thigh_r": Vector3(lerpf(0.9, 0.75, e), 0.0, -0.18),
				"knee_r": Vector3(-2.1, 0.0, 0.0), "torso": Vector3(lerpf(-0.1, 0.38, e), lerpf(0.0, -0.25, e), 0.0),
				"head": Vector3(lerpf(0.0, -0.3, e), 0.0, 0.0),
				"shoulder_r": Vector3(lerpf(0.9, 0.35, e), 0.0, lerpf(0.0, 0.95, e)), "elbow_r": Vector3(lerpf(1.6, 0.7, e), 0.0, 0.0),
				"shoulder_l": Vector3(lerpf(0.9, -0.55, e), 0.0, lerpf(0.0, -0.75, e)), "elbow_l": Vector3(lerpf(1.6, 0.5, e), 0.0, 0.0)}
		"spin_kick":     # foot reaches straight ahead at hip height (Task 7: thigh z -0.95 crossed it 45° to the left)
			var e2: float = _sm(u / 0.8)
			return {"thigh_r": Vector3(lerpf(0.9, 1.5, e2), 0.0, lerpf(-0.2, -0.3, e2)), "knee_r": Vector3(lerpf(-1.6, -0.05, e2), 0.0, 0.0),
				"torso": Vector3(lerpf(0.0, 0.32, e2), 0.0, lerpf(0.0, 0.42, e2)), "head": Vector3(0.0, 0.0, lerpf(0.0, -0.35, e2)),
				"shoulder_l": Vector3(0.6, 0.0, lerpf(0.3, -0.8, e2)), "elbow_l": Vector3(1.4, 0.0, 0.0),
				"shoulder_r": Vector3(0.3, 0.0, lerpf(-0.3, 0.9, e2)), "elbow_r": Vector3(1.0, 0.0, 0.0)}
		"scissor":
			var open_k: float = _sm(u / 0.4)
			var close_k: float = _sm((u - 0.42) / 0.3)
			var spread: float = open_k * (1.0 - 0.75 * close_k)
			return {"thigh_r": Vector3(0.2 + 1.35 * spread, 0.0, -0.1), "knee_r": Vector3(-0.15, 0.0, 0.0),
				"thigh_l": Vector3(0.2 - 0.95 * spread, 0.0, 0.1), "knee_l": Vector3(-0.35 - 0.4 * close_k, 0.0, 0.0),
				"torso": Vector3(-0.15, 0.0, 0.0), "head": Vector3(0.0, -0.4, 0.0),
				"shoulder_l": Vector3(1.6, 0.0, -0.4), "elbow_l": Vector3(0.3, 0.0, 0.0),
				"shoulder_r": Vector3(1.9, 0.0, 0.5), "elbow_r": Vector3(0.25, 0.0, 0.0)}
		"tuck":
			var k: float = sin(clampf(u, 0.0, 1.0) * PI)
			return {"thigh_l": Vector3(1.9 * k, 0.0, 0.1), "thigh_r": Vector3(1.9 * k, 0.0, -0.1), "knee_l": Vector3(-2.2 * k, 0.0, 0.0),
				"knee_r": Vector3(-2.2 * k, 0.0, 0.0), "torso": Vector3(0.5 * k, 0.0, 0.0), "head": Vector3(0.4 * k, 0.0, 0.0),
				"shoulder_l": Vector3(1.2 * k, 0.0, -0.2), "shoulder_r": Vector3(1.2 * k, 0.0, 0.2),
				"elbow_l": Vector3(1.4 * k, 0.0, 0.0), "elbow_r": Vector3(1.4 * k, 0.0, 0.0)}
		"dodge_lean":
			var k2: float = sin(clampf(u, 0.0, 1.0) * PI)
			return {"torso": Vector3(-0.45 * k2, 0.0, 0.25 * k2), "head": Vector3(-0.2 * k2, 0.0, 0.0),
				"knee_l": Vector3(-0.5 * k2, 0.0, 0.0), "knee_r": Vector3(-0.5 * k2, 0.0, 0.0),
				"shoulder_l": Vector3(1.1, 0.0, -0.4), "elbow_l": Vector3(2.0, 0.0, 0.0), "shoulder_r": Vector3(1.1, 0.0, 0.4), "elbow_r": Vector3(2.0, 0.0, 0.0)}
		"block":
			var k3: float = _sm(u / 0.3) * (1.0 - _sm((u - 0.7) / 0.3))
			return {"shoulder_l": Vector3(1.5 * k3 + 0.6, 0.0, -0.2), "elbow_l": Vector3(2.2, 0.0, 0.0),
				"shoulder_r": Vector3(1.5 * k3 + 0.6, 0.0, 0.2), "elbow_r": Vector3(2.2, 0.0, 0.0),
				"torso": Vector3(-0.15 * k3, 0.0, 0.0), "head": Vector3(0.2 * k3, 0.0, 0.0)}
		"knee":
			var k4: float = sin(clampf(u, 0.0, 1.0) * PI)
			return {"thigh_l": Vector3(1.7 * k4, 0.0, 0.0), "knee_l": Vector3(-2.2 * k4, 0.0, 0.0),
				"torso": Vector3(-0.25 * k4, 0.0, 0.0), "shoulder_l": Vector3(1.3, 0.0, -0.3), "shoulder_r": Vector3(1.3, 0.0, 0.3),
				"elbow_l": Vector3(1.5, 0.0, 0.0), "elbow_r": Vector3(1.5, 0.0, 0.0)}
		"spin_kick_add":   # additive on Kick_Right: swing the leg out and round, lean away (0 at both ends, peak at ADD_HIT)
			var ks: float = pow(sin(clampf(u, 0.0, 1.0) * PI), 2.0)
			return {"thigh_r": Vector3(0.15 * ks, 0.0, 0.55 * ks), "torso": Vector3(0.1 * ks, 0.0, 0.35 * ks),
				"head": Vector3(0.0, 0.0, -0.25 * ks), "shoulder_l": Vector3(0.0, 0.0, -0.5 * ks), "shoulder_r": Vector3(0.0, 0.0, 0.4 * ks)}
		"knee_add":        # additive on Kick_Left: lift the thigh higher and fold the shin into a knee (0 at both ends)
			var kk: float = pow(sin(clampf(u, 0.0, 1.0) * PI), 2.0)
			return {"thigh_l": Vector3(0.35 * kk, 0.0, 0.0), "knee_l": Vector3(-1.6 * kk, 0.0, 0.0), "torso": Vector3(-0.2 * kk, 0.0, 0.0)}
		"uppercut":   # additive on a left punch clip: drive the fist upward through the impact
			var k5: float = sin(clampf(u, 0.0, 1.0) * PI)
			return {"shoulder_l": Vector3(0.9 * k5, 0.0, 0.0), "elbow_l": Vector3(0.6 * k5, 0.0, 0.0), "torso": Vector3(-0.2 * k5, 0.0, 0.15 * k5)}
		"victory":
			var k6: float = _sm(u / 0.25)
			return {"shoulder_r": Vector3(2.9 * k6, 0.0, 0.3), "elbow_r": Vector3(0.3, 0.0, 0.0),
				"shoulder_l": Vector3(0.3, 0.0, -0.3), "torso": Vector3(-0.1 * k6, 0.0, 0.0), "head": Vector3(-0.25 * k6, 0.0, 0.0)}
		"lie_back":   # flat on the back, arms out, slow breathing (loop phase u)
			var br2: float = sin(u * TAU) * 0.02
			return {"body_pitch": PI * 0.5, "body_y": _lay_drop(PI * 0.5),
				"thigh_l": Vector3(0.35, 0.0, 0.1), "thigh_r": Vector3(0.05, 0.0, -0.12), "knee_l": Vector3(-0.6, 0.0, 0.0),
				"knee_r": Vector3(-0.1, 0.0, 0.0), "torso": Vector3(br2, 0.0, 0.0), "head": Vector3(0.1, 0.25, 0.0),
				"shoulder_l": Vector3(0.3, 0.0, -1.1), "elbow_l": Vector3(0.35, 0.0, 0.0),
				"shoulder_r": Vector3(0.15, 0.0, 0.9), "elbow_r": Vector3(0.5, 0.0, 0.0)}
		"fall_back":  # knocked out at the code tier: topple onto the back over the first 40 %, then lie_back
			var kf: float = _sm(u / 0.4)
			var lp: Dictionary = code_pose("lie_back", 0.0)
			var out: Dictionary = {}
			for j: String in lp.keys():
				if j == "body_y":
					continue
				out[j] = (lp[j] as Vector3) * kf if lp[j] is Vector3 else float(lp[j]) * kf
			out["body_y"] = _lay_drop(float(out["body_pitch"]))
			return out
		"getup":      # from lie_back: sit up (knees up, hands back on the floor), rock forward into a squat, stand up
			var g: Array = _getup_keys(u)   # [pitch, pivot height, thigh_l, knee_l, thigh_r, knee_r, shoulder x, shoulder z, elbow]
			return {"body_pitch": g[0], "body_y": float(g[1]) - PIVOT_Y,
				"thigh_l": Vector3(g[2], 0.0, 0.1), "knee_l": Vector3(g[3], 0.0, 0.0),
				"thigh_r": Vector3(g[4], 0.0, -0.1), "knee_r": Vector3(g[5], 0.0, 0.0),
				"head": Vector3(-0.15 * sin(clampf(u, 0.0, 1.0) * PI), 0.0, 0.0),
				"shoulder_l": Vector3(g[6], 0.0, -float(g[7])), "elbow_l": Vector3(g[8], 0.0, 0.0),
				"shoulder_r": Vector3(g[6], 0.0, g[7]), "elbow_r": Vector3(g[8], 0.0, 0.0)}
		"relaxed":    # standing at ease, arms down, slow breathing (loop phase u)
			var bb: float = sin(u * TAU) * 0.02
			return {"shoulder_l": Vector3(0.1, 0.0, -0.12), "elbow_l": Vector3(0.25, 0.0, 0.0), "shoulder_r": Vector3(0.1, 0.0, 0.12),
				"elbow_r": Vector3(0.25, 0.0, 0.0), "torso": Vector3(-0.03 - bb, 0.0, 0.0), "head": Vector3(bb, 0.0, 0.0)}
		"shove":
			return _kpose(SHOVE_KEYS, u)
		"shove_high":
			return _kpose(SHOVE_HIGH_KEYS, u)
		"grab":       # holding on, a little tug back and forth (loop phase u)
			var g2: Dictionary = GRAB.duplicate()
			g2["torso"] = (GRAB["torso"] as Vector3) + Vector3(0.0, 0.08 * sin(u * TAU), 0.0)
			return g2
		"headbutt":
			return _kpose(HEADBUTT_KEYS, u)
		"yank":
			return _kpose(YANK_KEYS, u)
		"hip_throw":
			return _kpose(HIP_THROW_KEYS, u)
		"thrown":     # thrown over the hip: limbs fly out, the body rolls onto its back (with the keys' forward flip)
			var kt: float = _sm(u)
			var lb: Dictionary = code_pose("lie_back", 0.0)
			var spread: float = sin(clampf((u - 0.2) / 0.8, 0.0, 1.0) * PI)   # limbs fly out once he is off the thrower
			var o2: Dictionary = {}
			for j2: String in lb.keys():
				if j2 == "body_pitch" or j2 == "body_y":
					continue
				o2[j2] = (lb[j2] as Vector3) * kt
			o2["shoulder_l"] = (o2["shoulder_l"] as Vector3) + Vector3(1.2, 0.0, -0.6) * spread
			o2["shoulder_r"] = (o2["shoulder_r"] as Vector3) + Vector3(1.2, 0.0, 0.6) * spread
			o2["thigh_l"] = (o2["thigh_l"] as Vector3) + Vector3(0.6, 0.0, 0.25) * spread
			o2["thigh_r"] = (o2["thigh_r"] as Vector3) + Vector3(0.2, 0.0, -0.25) * spread
			o2["knee_l"] = (o2["knee_l"] as Vector3) + Vector3(-0.8, 0.0, 0.0) * spread
			o2["body_pitch"] = PI * 0.5 * kt
			o2["body_y"] = _lay_drop(PI * 0.5 * kt)
			return o2
		"tackle":
			return _kpose(TACKLE_KEYS, u)
		"drive":      # driving him back with the shoulder: legs churn under the bent body (loop phase u)
			var ph: float = u * TAU
			var dr: Dictionary = TACKLE_LUNGE.duplicate()
			dr["thigh_l"] = Vector3(0.25 + 0.55 * sin(ph), 0.0, 0.08)
			dr["knee_l"] = Vector3(-0.85 - 0.45 * maxf(cos(ph), 0.0), 0.0, 0.0)
			dr["thigh_r"] = Vector3(0.25 - 0.55 * sin(ph), 0.0, -0.08)
			dr["knee_r"] = Vector3(-0.85 - 0.45 * maxf(-cos(ph), 0.0), 0.0, 0.0)
			dr["body_y"] = -0.16 + 0.03 * absf(sin(ph))
			return dr
		"doubled":    # folded over the tackler's shoulder, arms flung out sideways (clear of him), feet back-pedalling
			var ph2: float = u * TAU
			return {"torso": Vector3(-0.75, 0.0, 0.0), "head": Vector3(0.1, 0.0, 0.0),
				"shoulder_l": Vector3(0.35 + 0.15 * sin(ph2), 0.0, -1.55), "elbow_l": Vector3(0.4, 0.0, 0.0),
				"shoulder_r": Vector3(0.35 - 0.15 * sin(ph2), 0.0, 1.55), "elbow_r": Vector3(0.4, 0.0, 0.0),
				"thigh_l": Vector3(0.1 + 0.35 * sin(ph2), 0.0, 0.08), "knee_l": Vector3(-0.5 - 0.3 * maxf(cos(ph2), 0.0), 0.0, 0.0),
				"thigh_r": Vector3(0.1 - 0.35 * sin(ph2), 0.0, -0.08), "knee_r": Vector3(-0.5 - 0.3 * maxf(-cos(ph2), 0.0), 0.0, 0.0),
				"body_y": -0.08}
		"stunned":    # seeing stars: swaying on soft knees, arms hanging (loop phase u)
			var ph3: float = u * TAU
			return {"torso": Vector3(-0.1, 0.0, 0.12 * sin(ph3)), "head": Vector3(-0.15, 0.0, -0.25 * sin(ph3 + 0.6)),
				"shoulder_l": Vector3(0.3, 0.0, -0.3), "elbow_l": Vector3(0.4, 0.0, 0.0),
				"shoulder_r": Vector3(0.3, 0.0, 0.3), "elbow_r": Vector3(0.4, 0.0, 0.0),
				"thigh_l": Vector3(0.15, 0.0, 0.08), "knee_l": Vector3(-0.3, 0.0, 0.0),
				"thigh_r": Vector3(0.15, 0.0, -0.08), "knee_r": Vector3(-0.3, 0.0, 0.0), "body_y": -0.02}
		"winded":     # hands on the knees, heaving (loop phase u)
			var hv: float = sin(u * TAU) * 0.05
			return {"torso": Vector3(-0.8 - hv, 0.0, 0.0), "head": Vector3(0.6 + hv, 0.0, 0.0),
				"shoulder_l": Vector3(0.75, 0.0, -0.1), "elbow_l": Vector3(0.15, 0.0, 0.0),
				"shoulder_r": Vector3(0.75, 0.0, 0.1), "elbow_r": Vector3(0.15, 0.0, 0.0),
				"thigh_l": Vector3(0.5, 0.0, 0.1), "knee_l": Vector3(-0.75, 0.0, 0.0),
				"thigh_r": Vector3(0.5, 0.0, -0.1), "knee_r": Vector3(-0.75, 0.0, 0.0), "body_y": -0.1}
		"head_shake": # shaking the stars off
			var k7: float = sin(clampf(u, 0.0, 1.0) * PI)
			return {"head": Vector3(-0.1 * k7, 0.45 * sin(u * TAU * 2.5) * k7, 0.0), "torso": Vector3(-0.12 * k7, 0.0, 0.0),
				"shoulder_l": Vector3(0.15, 0.0, -0.15), "elbow_l": Vector3(0.3, 0.0, 0.0),
				"shoulder_r": Vector3(0.15, 0.0, 0.15), "elbow_r": Vector3(0.3, 0.0, 0.0)}
		"neck_crack":
			return _kpose(NECK_CRACK_KEYS, u)
		"pickup":
			return _kpose(PICKUP_KEYS, u)
		"slumped":    # sitting against what he was slammed into, knees up, head lolling (= getup's sitting key)
			var sl: Dictionary = code_pose("getup", GETUP_SIT_U)
			sl["head"] = Vector3(0.25, 0.2, 0.35 + 0.04 * sin(u * TAU))
			return sl
		"get_up_sit":
			return code_pose("getup", lerpf(GETUP_SIT_U, 1.0, clampf(u, 0.0, 1.0)))
		"sit_up":     # lying on the back: up onto the elbows and into the slumped sit (getup up to its sitting key)
			return code_pose("getup", lerpf(0.0, GETUP_SIT_U, clampf(u, 0.0, 1.0)))
		"hold_up":    # right forearm up, the held prop in front of the chest at reading distance; left arm relaxed
			var hb: float = sin(u * TAU) * 0.015
			return {"shoulder_r": Vector3(0.9 + hb, 0.0, 0.15), "elbow_r": Vector3(1.7, 0.0, 0.0),
				"shoulder_l": Vector3(0.1, 0.0, -0.12), "elbow_l": Vector3(0.25, 0.0, 0.0),
				"torso": Vector3(-0.03, 0.0, 0.0), "head": Vector3(0.28 + hb, 0.0, 0.0)}
		"sit_bench":  # upright on a seat ~0.45 m high: thighs level, shins down, hands in the lap, slow breathing
			var sb: float = sin(u * TAU) * 0.015
			return {"body_y": -0.43, "body_pitch": 0.05, "thigh_l": Vector3(1.55, 0.0, 0.06), "knee_l": Vector3(-1.55, 0.0, 0.0),
				"thigh_r": Vector3(1.55, 0.0, -0.06), "knee_r": Vector3(-1.55, 0.0, 0.0),
				"shoulder_l": Vector3(0.45, 0.0, -0.1), "elbow_l": Vector3(0.95, 0.0, 0.0),
				"shoulder_r": Vector3(0.45, 0.0, 0.1), "elbow_r": Vector3(0.95, 0.0, 0.0),
				"torso": Vector3(0.06 + sb, 0.0, 0.0), "head": Vector3(0.12 - sb, 0.0, 0.0)}
		"sit_bench_hold":   # seated, the right hand holding a prop up in front of the face
			var sh: Dictionary = code_pose("sit_bench", u)
			sh["shoulder_r"] = Vector3(0.95, 0.0, 0.15)
			sh["elbow_r"] = Vector3(1.75, 0.0, 0.0)
			sh["head"] = Vector3(0.22, 0.0, 0.0)
			return sh
		"nod":        # two small nods
			var kn: float = sin(clampf(u, 0.0, 1.0) * PI)
			return {"head": Vector3(0.28 * maxf(sin(u * TAU * 2.0), 0.0) * kn, 0.0, 0.0), "torso": Vector3(0.04 * kn, 0.0, 0.0),
				"shoulder_l": Vector3(0.1, 0.0, -0.12), "elbow_l": Vector3(0.25, 0.0, 0.0),
				"shoulder_r": Vector3(0.1, 0.0, 0.12), "elbow_r": Vector3(0.25, 0.0, 0.0)}
		"slammed":    # impact (hit), slammed back upright against it with arms flung out, then slides down to sit
			var sit: Dictionary = code_pose("slumped", 0.0)
			var keys: Array = [
				[0.0, {"body_pitch": 0.0, "body_y": 0.0, "torso": Vector3(-0.2, 0.0, 0.0), "head": Vector3(-0.1, 0.0, 0.0),
					"shoulder_l": Vector3(1.0, 0.0, -0.3), "elbow_l": Vector3(1.2, 0.0, 0.0), "shoulder_r": Vector3(1.0, 0.0, 0.3),
					"elbow_r": Vector3(1.2, 0.0, 0.0), "thigh_l": Vector3(0.1, 0.0, 0.1), "knee_l": Vector3(-0.2, 0.0, 0.0),
					"thigh_r": Vector3(0.1, 0.0, -0.1), "knee_r": Vector3(-0.2, 0.0, 0.0)}],
				[0.35, {"body_pitch": 0.3, "body_y": 0.0, "torso": Vector3(0.1, 0.0, 0.0), "head": Vector3(0.35, 0.0, 0.0),
					"shoulder_l": Vector3(0.6, 0.0, -1.0), "elbow_l": Vector3(0.3, 0.0, 0.0), "shoulder_r": Vector3(0.6, 0.0, 1.0),
					"elbow_r": Vector3(0.3, 0.0, 0.0), "thigh_l": Vector3(-0.3, 0.0, 0.1), "knee_l": Vector3(0.0, 0.0, 0.0),
					"thigh_r": Vector3(-0.3, 0.0, -0.1), "knee_r": Vector3(0.0, 0.0, 0.0)}],
				[0.65, {"body_pitch": 0.3, "body_y": -0.3, "torso": Vector3(0.05, 0.0, 0.0), "head": Vector3(0.3, 0.0, 0.2),
					"shoulder_l": Vector3(0.0, 0.0, -0.6), "elbow_l": Vector3(0.3, 0.0, 0.0), "shoulder_r": Vector3(0.0, 0.0, 0.6),
					"elbow_r": Vector3(0.3, 0.0, 0.0), "thigh_l": Vector3(1.1, 0.0, 0.1), "knee_l": Vector3(-1.3, 0.0, 0.0),
					"thigh_r": Vector3(1.1, 0.0, -0.1), "knee_r": Vector3(-1.3, 0.0, 0.0)}],
				[1.0, sit]]
			return _kpose(keys, u)
		"talk":       # explaining: the right hand gestures, the left moves a little, small nods (loop phase u)
			var w1: float = sin(u * TAU * 2.0)
			var w2: float = sin(u * TAU * 2.0 + 1.0)
			return {"shoulder_r": Vector3(0.45 + 0.12 * w1, 0.0, 0.22), "elbow_r": Vector3(1.35 + 0.25 * w2, 0.0, 0.0),
				"shoulder_l": Vector3(0.3 + 0.08 * sin(u * TAU + 2.0), 0.0, -0.18), "elbow_l": Vector3(1.0, 0.0, 0.0),
				"torso": Vector3(-0.03, 0.04 * w1, 0.0), "head": Vector3(0.05 * sin(u * TAU * 3.0), 0.0, 0.0)}
		"point":      # the right arm straight out at shoulder height (aim with the actor's yaw / a look cue)
			var pp: float = sin(u * TAU) * 0.02
			return {"shoulder_r": Vector3(1.45 + pp, 0.0, 0.12), "elbow_r": Vector3(0.08, 0.0, 0.0),
				"shoulder_l": Vector3(0.1, 0.0, -0.12), "elbow_l": Vector3(0.25, 0.0, 0.0), "torso": Vector3(-0.04, -0.1, 0.0)}
		"arms_crossed":
			var ab: float = sin(u * TAU) * 0.015
			return {"shoulder_l": Vector3(0.6, 0.0, 0.45), "elbow_l": Vector3(1.95, 0.0, 0.0), "shoulder_r": Vector3(0.55, 0.0, -0.45),
				"elbow_r": Vector3(2.0, 0.0, 0.0), "torso": Vector3(0.04 + ab, 0.0, 0.0), "head": Vector3(-0.05, 0.0, 0.0)}
		"confess":    # head down, hands clasped in front, knees a little soft (loop phase u)
			var cb: float = sin(u * TAU) * 0.03
			return {"head": Vector3(0.38 + cb, 0.0, 0.0), "torso": Vector3(-0.12, 0.0, 0.0),
				"shoulder_l": Vector3(0.5, 0.0, 0.28), "elbow_l": Vector3(1.25, 0.0, 0.0),
				"shoulder_r": Vector3(0.5, 0.0, -0.28), "elbow_r": Vector3(1.25, 0.0, 0.0),
				"thigh_l": Vector3(0.08, 0.0, 0.05), "knee_l": Vector3(-0.15, 0.0, 0.0), "thigh_r": Vector3(0.08, 0.0, -0.05),
				"knee_r": Vector3(-0.15, 0.0, 0.0)}
		"phone_call": # the right hand holds a phone at the ear, head tilted to it
			return {"shoulder_r": Vector3(0.8, 0.0, 0.75), "elbow_r": Vector3(2.5, 0.0, 0.0), "head": Vector3(0.05, 0.0, -0.12),
				"shoulder_l": Vector3(0.1, 0.0, -0.12), "elbow_l": Vector3(0.3, 0.0, 0.0)}
		"tray_hold":  # carrying a tray in front of the waist with both hands (hold with "mid": the prop sits between them)
			var tb: float = sin(u * TAU) * 0.01
			return {"shoulder_l": Vector3(0.55 + tb, 0.0, 0.15), "elbow_l": Vector3(1.3, 0.0, 0.0),
				"shoulder_r": Vector3(0.55 + tb, 0.0, -0.15), "elbow_r": Vector3(1.3, 0.0, 0.0), "head": Vector3(0.1, 0.0, 0.0)}
		"eat_sit":    # seated at a table, spoon to the mouth and back, the left hand by the bowl (loop phase u)
			var ek: float = pow(maxf(sin(u * TAU), 0.0), 2.0)
			var es: Dictionary = code_pose("sit_bench", u)
			es["shoulder_r"] = Vector3(0.55 + 0.45 * ek, 0.0, 0.18)
			es["elbow_r"] = Vector3(1.1 + 1.0 * ek, 0.0, 0.0)
			es["shoulder_l"] = Vector3(0.7, 0.0, -0.1)
			es["elbow_l"] = Vector3(1.1, 0.0, 0.0)
			es["head"] = Vector3(0.25 - 0.12 * ek, 0.0, 0.0)
			return es
		"stare_sit":  # seated, frozen mid-meal, hands flat on the table (a look cue turns the head)
			var ss: Dictionary = code_pose("sit_bench", u)
			ss["shoulder_l"] = Vector3(0.75, 0.0, -0.06)
			ss["elbow_l"] = Vector3(0.95, 0.0, 0.0)
			ss["shoulder_r"] = Vector3(0.75, 0.0, 0.06)
			ss["elbow_r"] = Vector3(0.95, 0.0, 0.0)
			ss["head"] = Vector3(0.0, 0.0, 0.0)
			return ss
		"mask_on":    # both hands up to the face (the mask appears at the peak, u 0.5) and down again
			var mk: float = sin(clampf(u, 0.0, 1.0) * PI)
			return {"shoulder_l": Vector3(0.1 + 1.25 * mk, 0.0, -0.12 + 0.37 * mk), "elbow_l": Vector3(0.25 + 2.0 * mk, 0.0, 0.0),
				"shoulder_r": Vector3(0.1 + 1.25 * mk, 0.0, 0.12 - 0.37 * mk), "elbow_r": Vector3(0.25 + 2.0 * mk, 0.0, 0.0),
				"head": Vector3(0.1 * mk, 0.0, 0.0)}
		"startled":   # jumps out of the skin: arms fly up and out, knees tuck (pair it with a key "arc" for the hop)
			var sk2: float = sin(clampf(u, 0.0, 1.0) * PI)
			return {"shoulder_l": Vector3(0.1 + 1.5 * sk2, 0.0, -0.12 - 0.6 * sk2), "elbow_l": Vector3(0.25 + 0.4 * sk2, 0.0, 0.0),
				"shoulder_r": Vector3(0.1 + 1.5 * sk2, 0.0, 0.12 + 0.6 * sk2), "elbow_r": Vector3(0.25 + 0.4 * sk2, 0.0, 0.0),
				"torso": Vector3(0.2 * sk2, 0.0, 0.0), "head": Vector3(-0.2 * sk2, 0.0, 0.0),
				"thigh_l": Vector3(0.5 * sk2, 0.0, 0.06), "knee_l": Vector3(-0.9 * sk2, 0.0, 0.0),
				"thigh_r": Vector3(0.5 * sk2, 0.0, -0.06), "knee_r": Vector3(-0.9 * sk2, 0.0, 0.0)}
		"cornered":   # backed off, palms out, leaning away, a nervous tremble (loop phase u)
			var tr: float = sin(u * TAU * 6.0) * 0.03
			return {"torso": Vector3(0.15, 0.0, 0.0), "head": Vector3(-0.05, tr, 0.0),
				"shoulder_l": Vector3(1.1 + tr, 0.0, -0.25), "elbow_l": Vector3(1.9, 0.0, 0.0),
				"shoulder_r": Vector3(1.1 - tr, 0.0, 0.25), "elbow_r": Vector3(1.9, 0.0, 0.0),
				"thigh_l": Vector3(0.12, 0.0, 0.06), "knee_l": Vector3(-0.25, 0.0, 0.0), "thigh_r": Vector3(-0.05, 0.0, -0.06),
				"knee_r": Vector3(-0.1, 0.0, 0.0)}
		"chair_smash":
			return _kpose(SMASH_KEYS, u)
		"step_back":  # one step back with the right foot, still carrying a tray (tray_hold arms)
			var kb: float = sin(clampf(u, 0.0, 1.0) * PI)
			var tb2: Dictionary = code_pose("tray_hold", 0.0)
			tb2["thigh_r"] = Vector3(-0.45 * kb, 0.0, -0.06)
			tb2["knee_r"] = Vector3(-0.35 * kb, 0.0, 0.0)
			tb2["thigh_l"] = Vector3(0.12 * kb, 0.0, 0.06)
			tb2["knee_l"] = Vector3(-0.1 * kb, 0.0, 0.0)
			tb2["torso"] = Vector3(0.12 * kb, 0.0, 0.0)
			return tb2
		"ride":       # astride a scooter seat (key the root up to the seat), hands on the handlebar, feet on the board
			var rd: Dictionary = code_pose("sit_bench", u)
			rd["thigh_l"] = Vector3(1.3, 0.0, 0.12)
			rd["thigh_r"] = Vector3(1.3, 0.0, -0.12)
			rd["knee_l"] = Vector3(-1.1, 0.0, 0.0)
			rd["knee_r"] = Vector3(-1.1, 0.0, 0.0)
			rd["shoulder_l"] = Vector3(1.25, 0.0, -0.2)
			rd["shoulder_r"] = Vector3(1.25, 0.0, 0.2)
			rd["elbow_l"] = Vector3(0.45, 0.0, 0.0)
			rd["elbow_r"] = Vector3(0.45, 0.0, 0.0)
			rd["torso"] = Vector3(-0.15, 0.0, 0.0)
			rd["head"] = Vector3(-0.1, 0.0, 0.0)
			return rd
		"type_sit":   # seated at a desk, forearms forward over the keyboard, fingers going (loop phase u)
			var ty: Dictionary = code_pose("sit_bench", u)
			var tj: float = sin(u * TAU * 6.0) * 0.03
			ty["shoulder_l"] = Vector3(0.7 + tj, 0.0, -0.06)
			ty["elbow_l"] = Vector3(1.25, 0.0, 0.0)
			ty["shoulder_r"] = Vector3(0.7 - tj, 0.0, 0.06)
			ty["elbow_r"] = Vector3(1.25, 0.0, 0.0)
			ty["torso"] = Vector3(0.14, 0.0, 0.0)
			ty["head"] = Vector3(0.18 + 0.03 * sin(u * TAU), 0.0, 0.0)
			return ty
		"sip":        # standing, a cup in the right hand: up to the mouth and down again (loop phase u)
			var sk: float = pow(maxf(sin(u * TAU), 0.0), 2.0)
			return {"shoulder_r": Vector3(0.55 + 0.75 * sk, 0.0, 0.2 + 0.15 * sk), "elbow_r": Vector3(1.5 + 0.8 * sk, 0.0, 0.0),
				"shoulder_l": Vector3(0.1, 0.0, -0.12), "elbow_l": Vector3(0.25, 0.0, 0.0),
				"torso": Vector3(-0.03, 0.0, 0.0), "head": Vector3(0.12 - 0.22 * sk, 0.0, 0.0)}
		"blow":       # the right hand at the mouth (a party horn), the left arm flung out: ta-da (loop phase u)
			var bw: float = sin(u * TAU) * 0.05
			return {"shoulder_r": Vector3(0.95, 0.0, 0.3), "elbow_r": Vector3(2.35, 0.0, 0.0),
				"shoulder_l": Vector3(1.2 + bw, 0.0, -1.0), "elbow_l": Vector3(0.3, 0.0, 0.0),
				"torso": Vector3(-0.1, 0.0, 0.0), "head": Vector3(-0.08 + bw, 0.0, 0.0)}
		"tied_sit":   # sitting against a pillar, hands tied behind it, head lolling (= slumped legs; loop phase u)
			var ts: Dictionary = code_pose("slumped", u)
			ts["shoulder_l"] = Vector3(-0.55, 0.0, -0.25)
			ts["elbow_l"] = Vector3(0.9, 0.0, 0.0)
			ts["shoulder_r"] = Vector3(-0.55, 0.0, 0.25)
			ts["elbow_r"] = Vector3(0.9, 0.0, 0.0)
			ts["head"] = Vector3(0.2, 0.15 * sin(u * TAU), 0.1)
			return ts
		"present":    # keynote: the right arm sweeps toward the screen, the left hand open (loop phase u)
			var pr: float = sin(u * TAU)
			return {"shoulder_r": Vector3(1.15 + 0.15 * pr, 0.0, 0.7), "elbow_r": Vector3(0.5, 0.0, 0.0),
				"shoulder_l": Vector3(0.75, 0.0, -0.45 - 0.1 * pr), "elbow_l": Vector3(1.1, 0.0, 0.0),
				"torso": Vector3(-0.05, 0.08 * pr, 0.0), "head": Vector3(-0.05, -0.1 * pr, 0.0)}
		"bow_ceo":    # a smug little bow, the right hand on the chest
			var bk: float = sin(clampf(u, 0.0, 1.0) * PI)
			return {"torso": Vector3(0.55 * bk, 0.0, 0.0), "head": Vector3(0.15 * bk, 0.0, 0.0),
				"shoulder_r": Vector3(0.6, 0.0, -0.55), "elbow_r": Vector3(2.0, 0.0, 0.0),
				"shoulder_l": Vector3(0.2, 0.0, -0.2), "elbow_l": Vector3(0.3, 0.0, 0.0)}
		"handshake":    # the right hand out at waist height, a few pumps; the left arm relaxed (two actors 0.85-0.9 m apart)
			var hp: float = sin(u * TAU * 2.0) * 0.08
			return {"shoulder_r": Vector3(0.62 + hp, 0.0, 0.05), "elbow_r": Vector3(0.55, 0.0, 0.0),
				"shoulder_l": Vector3(0.1, 0.0, -0.12), "elbow_l": Vector3(0.25, 0.0, 0.0),
				"torso": Vector3(0.06, 0.0, 0.0), "head": Vector3(0.05, 0.0, 0.0)}
		"facepalm":   # the right palm to the forehead, head down, a slow shake; eases in and out
			var fe: float = _sm(u / 0.22) * (1.0 - _sm((u - 0.8) / 0.2))
			return {"shoulder_r": Vector3(0.1 + 1.15 * fe, 0.0, 0.12 - 0.42 * fe), "elbow_r": Vector3(0.25 + 2.1 * fe, 0.0, 0.0),
				"shoulder_l": Vector3(0.1, 0.0, -0.12), "elbow_l": Vector3(0.25, 0.0, 0.0),
				"head": Vector3(0.38 * fe, 0.12 * sin(u * TAU * 2.0) * fe, 0.0), "torso": Vector3(-0.08 * fe, 0.0, 0.0)}
		"shrug":      # both forearms up and out, palms up, shoulders back, head tilted; eases in and out
			var se: float = _sm(u / 0.3) * (1.0 - _sm((u - 0.7) / 0.3))
			return {"shoulder_l": Vector3(0.1 + 0.3 * se, 0.0, -0.12 - 0.42 * se), "elbow_l": Vector3(0.25 + 1.2 * se, 0.0, 0.0),
				"shoulder_r": Vector3(0.1 + 0.3 * se, 0.0, 0.12 + 0.42 * se), "elbow_r": Vector3(0.25 + 1.2 * se, 0.0, 0.0),
				"head": Vector3(-0.05 * se, 0.0, 0.18 * se), "torso": Vector3(0.06 * se, 0.0, 0.0)}
		"laugh":      # leaning back, hands on the belly, shoulders bouncing (loop phase u)
			var lb: float = sin(u * TAU * 4.0)
			return {"torso": Vector3(0.16 + 0.05 * lb, 0.0, 0.0), "head": Vector3(-0.28 + 0.06 * lb, 0.0, 0.0),
				"shoulder_l": Vector3(0.45 + 0.05 * lb, 0.0, 0.22), "elbow_l": Vector3(1.55, 0.0, 0.0),
				"shoulder_r": Vector3(0.45 + 0.05 * lb, 0.0, -0.22), "elbow_r": Vector3(1.55, 0.0, 0.0)}
		"block_high":   # arms up over the head (a weapon held across it), braced for the blow, then down a little
			var bh: float = _sm(u / 0.35) * (1.0 - 0.3 * _sm((u - 0.6) / 0.4))
			return {"shoulder_l": Vector3(2.7 * bh, 0.0, -0.35 * bh), "elbow_l": Vector3(0.7 * bh, 0.0, 0.0),
				"shoulder_r": Vector3(2.7 * bh, 0.0, 0.35 * bh), "elbow_r": Vector3(0.7 * bh, 0.0, 0.0),
				"torso": Vector3(-0.12 * bh, 0.0, 0.0), "head": Vector3(-0.3 * bh, 0.0, 0.0),
				"knee_l": Vector3(-0.3 * bh, 0.0, 0.0), "knee_r": Vector3(-0.3 * bh, 0.0, 0.0)}
		"staff_guard":  # both hands on a staff held forward at waist height, knees soft (loop phase u)
			var sg: float = sin(u * TAU) * 0.02
			return {"shoulder_l": Vector3(0.95 + sg, 0.0, 0.3), "elbow_l": Vector3(1.0, 0.0, 0.0),
				"shoulder_r": Vector3(0.75 + sg, 0.0, -0.05), "elbow_r": Vector3(1.35, 0.0, 0.0),
				"torso": Vector3(0.1, 0.25, 0.0), "head": Vector3(-0.05, -0.25, 0.0),
				"thigh_l": Vector3(0.25, 0.0, 0.08), "knee_l": Vector3(-0.4, 0.0, 0.0),
				"thigh_r": Vector3(-0.1, 0.0, -0.08), "knee_r": Vector3(-0.3, 0.0, 0.0)}
		"tray_guard":   # both forearms up in front of the face behind a tray (held "mid"), braced; a small shake (loop phase u)
			var tg: float = sin(u * TAU * 2.0) * 0.015
			return {"shoulder_l": Vector3(1.85 + tg, 0.0, -0.25), "elbow_l": Vector3(1.95, 0.0, 0.0),
				"shoulder_r": Vector3(1.85 - tg, 0.0, 0.25), "elbow_r": Vector3(1.95, 0.0, 0.0),
				"torso": Vector3(-0.12, 0.0, 0.0), "head": Vector3(0.18, 0.0, 0.0),
				"thigh_l": Vector3(0.25, 0.0, 0.08), "knee_l": Vector3(-0.4, 0.0, 0.0),
				"thigh_r": Vector3(-0.1, 0.0, -0.08), "knee_r": Vector3(-0.3, 0.0, 0.0)}
		"dangle":       # hung by the collar off a crane hook: chin down, arms flailing out, legs kicking (loop phase u)
			var dk: float = sin(u * TAU * 2.0)
			return {"torso": Vector3(-0.12, 0.0, 0.05 * dk), "head": Vector3(-0.25, 0.0, 0.0),
				"shoulder_l": Vector3(0.7 + 0.5 * dk, 0.0, -0.6), "elbow_l": Vector3(0.8, 0.0, 0.0),
				"shoulder_r": Vector3(0.7 - 0.5 * dk, 0.0, 0.6), "elbow_r": Vector3(0.8, 0.0, 0.0),
				"thigh_l": Vector3(0.35 + 0.4 * dk, 0.0, 0.06), "knee_l": Vector3(-0.45 - 0.35 * dk, 0.0, 0.0),
				"thigh_r": Vector3(0.35 - 0.4 * dk, 0.0, -0.06), "knee_r": Vector3(-0.45 + 0.35 * dk, 0.0, 0.0)}
		# --- W6 stream C, seg_d5_boss poses
		"staff_thrust":
			return _kpose(STAFF_THRUST_KEYS, u)
		"staff_sweep":  # down into a deep crouch for the low sweep, held through the sweep, back up to the guard
			return _kpose(STAFF_SWEEP_KEYS, u)
		"staff_swing":  # the staff raised across to head height for the spinning strike, held through it, back down
			return _kpose(STAFF_SWING_KEYS, u)
		"staff_run":    # a short sprint carrying the staff forward in both hands (only the legs swing; loop phase u)
			var rp: float = sin(u * TAU)
			return {"thigh_l": Vector3(0.25 + 0.65 * rp, 0.0, 0.06),
				"knee_l": Vector3(-0.35 - 0.55 * maxf(0.0, -rp) - 0.25 * maxf(0.0, rp), 0.0, 0.0),
				"thigh_r": Vector3(0.25 - 0.65 * rp, 0.0, -0.06),
				"knee_r": Vector3(-0.35 - 0.55 * maxf(0.0, rp) - 0.25 * maxf(0.0, -rp), 0.0, 0.0),
				"torso": Vector3(-0.3, 0.0, 0.0), "head": Vector3(0.25, 0.0, 0.0),
				"shoulder_l": Vector3(0.9, 0.0, 0.25), "elbow_l": Vector3(0.9, 0.0, 0.0),
				"shoulder_r": Vector3(0.7, 0.0, -0.05), "elbow_r": Vector3(1.2, 0.0, 0.0), "body_y": 0.03 * absf(rp)}
		"katana_slash":
			return _kpose(KATANA_SLASH_KEYS, u)
		"blown_back":   # kicked in the chest: folded at the waist, flung onto his back, arms thrown forward, legs trailing (loop u)
			var bb: float = sin(u * TAU) * 0.08
			return {"body_pitch": 0.5, "torso": Vector3(-0.35, 0.0, 0.0), "head": Vector3(-0.2, 0.0, 0.0),
				"shoulder_l": Vector3(1.3 + bb, 0.0, -0.4), "elbow_l": Vector3(0.4, 0.0, 0.0),
				"shoulder_r": Vector3(1.3 - bb, 0.0, 0.4), "elbow_r": Vector3(0.4, 0.0, 0.0),
				"thigh_l": Vector3(0.45 - bb, 0.0, 0.1), "knee_l": Vector3(-0.5, 0.0, 0.0),
				"thigh_r": Vector3(0.3 + bb, 0.0, -0.1), "knee_r": Vector3(-0.35, 0.0, 0.0)}
		# --- end W6 stream C, seg_d5_boss poses
	return {}
