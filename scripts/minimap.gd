extends Control
# Radar kecil di pojok kiri atas.

var game


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
	if game == null or game.player == null or not is_instance_valid(game.player):
		return
	var pp: Vector3 = game.player.global_position
	var sc: float = size.x * 0.5 / 55.0
	var c := size * 0.5
	if game.zone_active:
		var zc := c + Vector2(-pp.x, -pp.z) * sc
		draw_arc(zc, float(game.zone_radius) * sc, 0.0, TAU, 64, Color(0.3, 0.6, 1.0), 2.0)
	for f in get_tree().get_nodes_in_group("fighters"):
		if f == game.player or not f.alive:
			continue
		var rel := Vector2(f.global_position.x - pp.x, f.global_position.z - pp.z) * sc
		var lim: float = size.x * 0.5 - 4.0
		if rel.length() > lim:
			rel = rel.normalized() * lim
		draw_circle(c + rel, 3.0, game.team_color(f.team))
	var yaw: float = game.player.rotation.y
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	draw_line(c, c + fwd * 14.0, Color.WHITE, 2.0)
	draw_circle(c, 4.0, Color.WHITE)
