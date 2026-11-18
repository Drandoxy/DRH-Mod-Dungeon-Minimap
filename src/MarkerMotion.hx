package mods.dungeon_minimap;

/** World-space smoothing, independent of map zoom/pan. */
class MarkerMotion {
	public var x:Float;
	public var y:Float;

	var time:Int;

	public function new(x:Float, y:Float, now:Int) {
		this.x = x;
		this.y = y;
		time = now;
	}

	public function move(tx:Float, ty:Float, now:Int):Void {
		var dt = now - time;
		time = now;
		var dx = tx - x;
		var dy = ty - y;
		if (dt > 250 || dx * dx + dy * dy > 180 * 180) {
			x = tx;
			y = ty;
			return;
		}
		var blend = 1 - Math.exp(-Math.max(0, dt) / 60);
		x += dx * blend;
		y += dy * blend;
		if (Math.abs(tx - x) < 0.01)
			x = tx;
		if (Math.abs(ty - y) < 0.01)
			y = ty;
	}
}
