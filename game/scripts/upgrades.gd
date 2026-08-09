class_name Upgrades
extends RefCounted
## The upgrade catalog: what each pick changes, the plain-language line that
## explains it, and the effect itself.
##
## `apply_to()` is the ONLY place upgrade math lives, and `preview()` runs that
## same function on a copy of the mods — so a card can never advertise a number
## the upgrade doesn't actually deliver.

## Every upgrade belongs to one of five systems. The colour ties the card to
## the thing it changes on screen: cyan beam, gold turrets, kill blasts orange.
const CATEGORIES := {
	&"beam": {label = "BEAM", color = Color(0.45, 0.95, 1.15)},
	&"turrets": {label = "TURRETS", color = Color(1.0, 0.85, 0.4)},
	&"core": {label = "CORE", color = Color(0.55, 1.0, 0.75)},
	&"mass": {label = "MASS", color = Color(0.78, 0.72, 1.0)},
	&"blast": {label = "BLAST", color = Color(1.0, 0.62, 0.42)},
}

## stat kinds: num (plain value) · int · plus (shown as +N) · pct (0..1 as %)
## · rate (a seconds-between-shots interval, shown as shots per second)
const CATALOG := [
	{
		id = &"beam_power",
		title = "Hotter Beam",
		cat = &"beam",
		blurb = "Whatever you hold the beam on dies faster.",
		detail = "Your beam deals damage continuously for as long as you hold it on a target, and this raises how much. Nothing about aiming changes — the same enemy simply dies in fewer seconds. Take it when single tough enemies are surviving long enough to reach your ring.",
		stats = [{label = "Beam damage", key = "beam_power", kind = &"num", suffix = "/sec"}],
	},
	{
		id = &"beam_width",
		title = "Wider Beam",
		cat = &"beam",
		blurb = "A thicker beam, so rough aim still connects — and it covers more of a crowd at once.",
		detail = "The beam is a thick line, not a hairline, and this makes it thicker. An enemy is hit whenever any part of it touches that line, so a wider beam forgives loose aim and can hold two or three enemies at once as they close in. Best when fast movers keep slipping past your aim, or when you'd rather sweep a crowd than pick one target.",
		stats = [{label = "Beam width", key = "beam_width", kind = &"num"}],
	},
	{
		id = &"lance",
		title = "Piercing Beam",
		cat = &"beam",
		blurb = "The beam punches through what it hits and keeps damaging enemies lined up behind it.",
		detail = "Your beam already hits everything standing in its line, but each enemy behind the first one takes only a fraction of the damage. This raises that fraction, so the second, third and fourth enemy in a queue take far more than they used to. It is strongest when enemies stream in from one direction — line them up and a single held beam damages the whole column.",
		stats = [{label = "Damage carried through", key = "beam_pierce", kind = &"pct"}],
	},
	{
		id = &"magnet",
		title = "Stronger Pull",
		cat = &"mass",
		blurb = "Mass shards fly to your star from further out (the faint ring around you), so kills pay out sooner.",
		detail = "Dead enemies scatter mass shards, and a shard only races home once it is inside your pull range — the faint ring drawn around your star. This widens that ring, so shards start flying in immediately instead of drifting toward you. You still collect everything eventually; this decides how quickly, which decides how fast you hit the next ring level and the next upgrade.",
		stats = [{label = "Pull range", key = "magnet_radius", kind = &"num"}],
	},
	{
		id = &"bounty",
		title = "Richer Kills",
		cat = &"mass",
		blurb = "Every enemy drops extra shards, so you reach the next ring level faster.",
		detail = "Each kill bursts into shards, and every shard that reaches you is mass. This adds an extra shard to every single kill, on top of whatever that enemy already dropped. It doesn't help you kill anything faster — it makes each kill worth more, which compounds over a long run into noticeably more ring levels and more upgrade picks.",
		stats = [{label = "Bonus shards per kill", key = "shard_bounty", kind = &"plus"}],
	},
	{
		id = &"turret_add",
		title = "Extra Turret",
		cat = &"turrets",
		blurb = "Another turret crystallizes onto your ring. Turrets pick their own targets and fire without you.",
		detail = "Turrets are the small gold diamonds sitting on your accretion ring. Each one finds the nearest enemy in its range and fires on its own — you never aim or trigger them, so they keep working while your beam is pointed somewhere else. Adding one is a flat increase in damage you don't have to manage, and turrets space themselves evenly around the ring, so more of them means more directions covered.",
		stats = [{label = "Turrets", key = "turret_count", kind = &"int"}],
	},
	{
		id = &"turret_power",
		title = "Stronger Turrets",
		cat = &"turrets",
		blurb = "Every turret shot hits harder.",
		detail = "Each shot fired by each of your turrets does more damage. Because it applies to every turret you own, it gets stronger the more hardpoints you've crystallized: modest with one turret, excellent with four. If you have no spare turrets yet, Extra Turret is usually the better pick first.",
		stats = [{label = "Turret damage", key = "turret_power", kind = &"num", suffix = "/shot"}],
	},
	{
		id = &"turret_rate",
		title = "Faster Turrets",
		cat = &"turrets",
		blurb = "Turrets shoot more often — damage that keeps landing while your beam is aimed elsewhere.",
		detail = "Turrets pause for a fixed moment between shots, and this shortens the pause. Same damage per shot, more shots per second, on every turret you own. Like Stronger Turrets it multiplies with how many turrets you have, and it's the better of the two against small, numerous enemies that die to any single hit.",
		stats = [{label = "Turret fire rate", key = "turret_rate", kind = &"rate", suffix = " shots/sec"}],
	},
	{
		id = &"plating",
		title = "Thicker Plating",
		cat = &"core",
		blurb = "One more hit your core can take before the run ends.",
		detail = "The pips at the bottom left are your integrity. Any enemy that touches your ring destroys itself and costs you one pip, and the run ends at zero. This raises the maximum by one and repairs one point immediately, so it's both a bigger buffer and an instant heal. Worth grabbing when you're down to a pip or two — reaching a new ring level also repairs one.",
		note = "Repairs 1 damage right now.",
		stats = [{label = "Integrity", key = "max_hp", kind = &"int"}],
	},
	{
		id = &"nova",
		title = "Bigger Kill Blast",
		cat = &"blast",
		blurb = "Every kill detonates and damages nearby enemies, so packed waves chain-react into each other.",
		detail = "Every enemy you kill detonates, damaging anything caught inside the blast ring that flashes on each death. That means kills chain: one death wounds its neighbours, they die sooner, and their blasts carry on through the pack. This raises both the damage and the radius, which makes it the strongest answer to surge waves — the moment enemies are packed tightly enough, the chain does the work for you.",
		stats = [
			{label = "Blast damage", key = "nova_power", kind = &"num"},
			{label = "Blast radius", key = "nova_radius", kind = &"num"},
		],
	},
]

static func by_id(id: StringName) -> Dictionary:
	for u in CATALOG:
		if u.id == id:
			return u
	return {}

static func category_of(id: StringName) -> Dictionary:
	var u := by_id(id)
	if u.is_empty():
		return CATEGORIES[&"core"]
	return CATEGORIES[u.cat]

## The single source of upgrade math. GameState applies it for real; the cards
## apply it to a throwaway copy to show the player the resulting number.
static func apply_to(mods: Dictionary, id: StringName) -> void:
	match id:
		&"beam_power": mods.beam_power *= 1.35
		&"beam_width": mods.beam_width *= 1.25
		&"magnet": mods.magnet_radius *= 1.3
		&"turret_add": mods.turret_count += 1
		&"turret_power": mods.turret_power *= 1.3
		&"turret_rate": mods.turret_rate = maxf(0.12, mods.turret_rate * 0.78)
		&"plating": mods.max_hp += 1
		&"bounty": mods.shard_bounty += 1
		&"lance": mods.beam_pierce = minf(1.0, mods.beam_pierce + 0.22)
		&"nova":
			mods.nova_power *= 1.45
			mods.nova_radius *= 1.15

## Rows of {label, from, to} showing what this pick would do to `mods` right
## now — the concrete before/after the card puts in front of the player.
static func preview(id: StringName, mods: Dictionary) -> Array:
	var after := mods.duplicate()
	apply_to(after, id)
	var rows := []
	for s in by_id(id).get("stats", []):
		var a: float = float(mods.get(s.key, 0.0))
		var b: float = float(after.get(s.key, 0.0))
		var pair := _fmt_pair(s, a, b)
		rows.append({label = s.label, from = pair[0], to = pair[1]})
	return rows

## Both halves of a before/after pair share a decimal count, so a row reads
## "8.0 » 11.6" or "26 » 35" — never "8.0 » 12". The unit rides on the second
## value only: "26 » 35/sec" rather than the same word twice.
static func _fmt_pair(spec: Dictionary, a: float, b: float) -> Array:
	var kind: StringName = spec.get("kind", &"num")
	var suffix: String = spec.get("suffix", "")
	match kind:
		&"int":
			return ["%d" % roundi(a), "%d%s" % [roundi(b), suffix]]
		&"plus":
			return ["+%d" % roundi(a), "+%d%s" % [roundi(b), suffix]]
		&"pct":
			return ["%d%%" % roundi(a * 100.0), "%d%%%s" % [roundi(b * 100.0), suffix]]
		&"rate":
			# stored as seconds between shots; players think in shots per second
			a = 1.0 / maxf(a, 0.001)
			b = 1.0 / maxf(b, 0.001)
	var decimals := 1 if minf(absf(a), absf(b)) < 20.0 else 0
	return ["%.*f" % [decimals, a], "%.*f%s" % [decimals, b, suffix]]

## One-line summary of a pick that was just applied, for the confirmation toast.
static func change_line(rows: Array) -> String:
	var parts := PackedStringArray()
	for r in rows:
		parts.append("%s  %s » %s" % [r.label, r.from, r.to])
	return "   •   ".join(parts)
