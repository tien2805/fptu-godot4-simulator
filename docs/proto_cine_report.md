# Prototype report: in-engine fight cinematic (seg_d1_brawl), stopped as WIP

Branch `proto-cine` (from vice-people 54c6f18). Stopped on the controller's instruction before choreography, video and stills: the sample cinematic will be rebuilt on Mixamo mocap with a data-driven timeline. No video was rendered. What exists is the retargeting layer, which is verified, plus a rough first pass of the scene.

## What was built

| File | State |
|---|---|
| `assets/models/quaternius/anim_library/` | Quaternius UAL1 (46 clips) and UAL2 (43 clips), CC0, with licenses and `CREDITS.md`. |
| `scripts/cine/CineRetarget.gd` | **Done and verified.** Runtime retargeter: UAL1 / UAL2 onto the game's Quaternius Modular bodies, plus the bodies' own clips ("native"). |
| `tests/preview_cine_retarget.gd` | Contact-sheet tool. For each clip it shows N time samples, with the library's own mannequin on the left and the game's PS2 person on the right. Run `godot --path . --resolution 1800x560 --script tests/preview_cine_retarget.gd` with `CLIPS="ual2:Melee_Hook,..."`, `STEPS`, `VIEW=front/side/threequarter` and `PRESET`. |
| `scripts/cine/CineActor.gd` | Works. Actor wrapper driven purely by story time, so you can seek to any frame. It handles clip crossfades, code-pose overrides through `CharacterBuilder._apply_bone_pose` (absolute) or `_char_rot_local` (additive), keyframed root position and yaw with ballistic arcs, a "spin" pivot at hip height for flips and airborne rolls, and PS2 face cells. |
| `scripts/cine/CineTimeWarp.gd` | Works. Real time ↔ story time: per hit it eases from 1× down to k, holds, freezes, then eases back to 1×. The real length is fixed (25.0 s). It produces the beat rows (real hit time, freeze end). |
| `scripts/cine/CineAlley.gd` | First pass of the night alley set, all built in code. Wet asphalt uses noise-driven roughness plus SSR, there are pastel walls, roll-up shutters, TextMesh neon signs with coloured lights (fictional names), a lamp post, palms, a delivery scooter with a box, and crates with pre-built debris. |
| `scripts/cine/CineBrawl.gd`, `scenes/proto/CineBrawl.tscn` | **Rough WIP, not tuned.** It has 8 hits plus the ramps, a first-draft script for 4 actors, 12 camera shots, sparks, dust and splash CPUParticles3D driven by `speed_scale`, a shockwave, ballistic crate debris, letterbox, fade, flash, vignette, a synthesized tick per hit, a beat-sheet writer, a seek/still mode (`CINE_SEEK`, `CINE_SEEK_S`), a blocking ortho camera (`CINE_CAM=side/top`) and a debug overlay (`CINE_DEBUG=1`). |
| `docs/preview/proto_retarget_sheet_1.png`, `_sheet_2.png`, `_closeup.png` | Retarget verification sheets: mannequin on the left, game character on the right. |
| `docs/preview/proto_cine_wip_blocking.png` | First seek stills of the WIP scene (look test only). |

## How the retargeting works

The game body (Quaternius Modular, bones `Hips/Torso/Chest/UpperArm.L/...`) has an odd rest pose: arms hanging diagonally, pelvis yawed about 27°, left leg rotated out, mid-stride. The source rests in a T-pose. Both models face +Z with +X as the character's left, and they share a common model frame.

Per target bone `b` with source bone `s`, the retargeter computes once, at bind time:

- `A_b` is a model-frame rotation that moves the target bone from its own rest pose into the pose matching the source's rest pose. `A_b` depends on the bone class:
  - `delta` (torso, chest, neck, head, clavicles): `A = I`.
  - `yaw` (Body, Hips, Abdomen): rotation about Y only, so the forward axes match. This removes the 27° pelvis yaw.
  - `dir` (arms, hands, fingers): shortest arc from the target bone's Y axis (along the bone) to the source bone's Y axis.
  - `leg` (thigh, shin): match the frame made of the bone axis and the knee direction. The target's knee direction is measured from its rest geometry; the source's is forward.
  - `foot`: match the frame made of up and the horizontal toe direction.
- `O_b = R_s⁻¹ · A_b · R_t`, where `R` is the global rest rotation.

Every frame, `G_t = G_s(t) · O_b`. In words: the target bone turns by exactly the source bone's rotation away from the matched pose. Globals are converted to locals parent-first.

Positions:
- The midpoint of the target's hip joints is set to the source's hip midpoint × `k`, where `k` is the leg-length ratio. The Body bone is offset to match.
- The target feet are IK-target bones under Root. They are re-attached rigidly at the shin's ankle, the same way `CharacterBuilder._apply_bone_pose` does it, and take their orientation from the source foot.

The output is a local pose dictionary. It can be blended between clips and written to the skeleton, and code overrides go on top using the game's own bone helper.

**Verified visually** on about 30 clips: Idle, Sprint, Jog, Punch_Jab, Punch_Cross, Punch_Enter, Melee_Hook(+Rec), NinjaJump_Start/Idle/Land, Hit_Knockback, Hit_Head, Hit_Chest, Death01, LayToIdle, Slide/Slide_Start/Slide_Exit, Roll, Jump*, Sword_Attack, OverhandThrow, Sword_Regular_A, Idle_No, Idle_FoldArms, and native Kick_Right, Roll, Death and HitRecieve. Poses match the source closely, including closed fists, knee direction, flat feet, and airborne and lying poses. I saw no broken joints or flipped limbs on the hoodie or casual male bodies.

## What works / what doesn't yet

Works:
- Retargeting quality is good enough to build on.
- Seeking to any frame and the blocking camera make iteration quick: one seek run is about 30-60 s.
- The vice night look carries well into the fight area. The wet ground reflects the neon nicely in the first stills, which is the most promising visual element.
- The time-warp clock is solid.

Not done, or wrong:
- No choreography tuning. Contacts don't line up: the flying kick lands about 0.9 m short of courier 1, and the kick leg points up instead of forward.
- Camera framing is untuned.
- The shockwave ring reads as a "portal" and should be removed or made subtle.
- A soft white disc appears at ground level under the flying kick. Its source was being investigated when work stopped: probably a particle quad emitted at the wrong position, not a light highlight.
- The code poses (flying kick, spin kick, scissor) are hand-tuned Euler angles relative to the body's odd rest pose. That makes them slow to author and likely stiff, which is exactly why mocap is the better source.
- Not done at all: the beat sheet file, the video and the stills.
- Feet can slide or float a few cm, because the retargeter matches bone directions, not foot positions. Ground contact would need two-bone IK foot planting.

Time spent, roughly: 25 min on recon and asset inspection, 45 min on the retargeter and verification sheets, 60 min on the actor, time-warp, set, director and first seek stills.

## Making the same retargeter accept a Mixamo FBX source (`mixamorig:*`)

The math in `CineRetarget` is source-agnostic. Only the source description is per library. To add Mixamo:

1. **Import.** Godot 4 imports FBX natively (ufbx). Import each Mixamo clip "Without Skin" (or one skinned file plus animation-only files). Mixamo exports at 1 unit = 1 cm with a 100× scale on the armature node, so read skeleton rests and position tracks in the skeleton's own space and scale hip translation by the hip-height ratio, which `k` already does. Set the importer to keep the bone names: no BoneMap/retarget in the import settings, because ours is a runtime retarget. Put the clips in `assets/models/mixamo/` (check Mixamo's licence terms for redistribution in a repo or a shipped build first).
2. **Bone names.** Track subnames come through as `mixamorig:Hips`, or `mixamorig_Hips` depending on the importer. Normalise them by stripping the prefix in `_read_skeleton` / `_tracks_of`, and add a third column to `bone_map()`:
   - Body/Hips → `Hips`, Abdomen → `Spine`, Torso → `Spine1`, Chest → `Spine2`, Neck → `Neck`, Head → `Head`
   - Shoulder.L → `LeftShoulder`, UpperArm.L → `LeftArm`, LowerArm.L → `LeftForeArm`, Wrist.L → `LeftHand`
   - Index1-3.L → `LeftHandIndex1-3`, and the same for Middle, Ring and Pinky; Thumb1-3.L → `LeftHandThumb1-3`
   - UpperLeg.L → `LeftUpLeg`, LowerLeg.L → `LeftLeg`, Foot.L → `LeftFoot` (Mixamo also has `LeftToeBase`, which the target lacks)
   - mirror all of this for Right.
3. **Generalise the lib table.** Replace `LIB_FILES` and the `col` index (1 = ual1, 2 = ual2) with a source descriptor: `{file or folder of clips, name-normaliser, column}`. With Mixamo, one FBX holds one clip, so `lib()` should merge many files into one `anims` dictionary keyed by clip name, using the rest skeleton of the first file. All Mixamo exports share the same rig, so that is safe if they all come from the same character.
4. **Rest-pose conventions.** Mixamo rests in a T-pose facing +Z with Y-up after import, the same as UAL, so the `delta / yaw / dir / leg / foot` classes apply unchanged. The two things to re-check with `tests/preview_cine_retarget.gd`:
   - Mixamo bone local axes. Godot's FBX import keeps the Y axis along the bone, which `dir` and `leg` rely on. If any bone isn't Y-along-bone, compute the bone direction from the child joint position instead of `basis.y`; that is a small change in `_align`.
   - The source "forward" for `yaw` and `leg`. It is +Z after import; verify it with one Idle sheet.
5. **Root motion.** Mixamo clips are often exported "in place" with the forward motion stripped, or with root motion baked into `Hips`. For flips and kicks keep the hip translation (the retargeter already carries the hip translation into the Body position). For travelling moves, either use the in-place version and move the actor root with timeline keys (as `CineActor.key` already does), or extract the hips' horizontal delta into the actor root.
6. **Timeline.** `CineActor`'s `clip / key / override / expr` calls are already a tiny data model. A data-driven timeline (JSON or a `.tres` per cinematic: actors, clip cues, root keys, hits with slow/freeze parameters, camera shots, FX cues) can feed them directly. `CineTimeWarp` and the beat-sheet writer are reusable as they are.

Expected effort: about half a day to make the retargeter source-generic and add the Mixamo map. Visually verifying 10-20 Mixamo clips with the contact-sheet tool is fast. The real cost of 20 cinematics stays per scene: blocking contacts, camera shots and FX timing. Mocap removes the hand-posed acrobatics, which were the slowest and least convincing part.
