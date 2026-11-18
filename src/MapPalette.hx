package mods.dungeon_minimap;

import mods.api.Context;

/** Shared tile catalogue; selection runs only when a floor is drawn. */
class MapPalette {
	static var tileThemes:Map<String, String>;

	public var outside:Int;
	public var floor:Int;
	public var wall:Int;
	public var edge:Int;
	public var hatch:Int;

	function new(outside:Int, floor:Int, wall:Int, edge:Int, hatch:Int) {
		this.outside = outside;
		this.floor = floor;
		this.wall = wall;
		this.edge = edge;
		this.hatch = hatch;
	}

	public static function releaseCache():Void {
		tileThemes = null;
	}

	public static function detect(ctx:Context):MapPalette {
		if (tileThemes == null) {
			tileThemes = new Map();
			try {
				var data:Dynamic = haxe.Json.parse(sys.io.File.getContent(ctx.resources + "/tile_themes.json"));
				for (id in Reflect.fields(data))
					tileThemes.set(id, Std.string(Reflect.field(data, id)));
			} catch (e:Dynamic) {
				ctx.log("minimap: tile themes unavailable: " + Std.string(e));
			}
		}
		var floor = ctx.state.floor;
		if (floor == null)
			return forTheme("arena");
		var votes:Map<String, Int> = new Map();
		var selected = "arena";
		var most = 0;
		// Exclude filler and IDs reused across families. Majority beats a shared boss tile.
		for (tile in floor.tiles) {
			if (tile.category == "FILLER_TILE")
				continue;
			var theme = tileThemes.get(tile.id);
			if (theme == null)
				continue;
			var count = votes.exists(theme) ? votes.get(theme) + 1 : 1;
			votes.set(theme, count);
			if (count > most) {
				selected = theme;
				most = count;
			}
		}
		return forTheme(selected);
	}

	public static function forTheme(theme:String):MapPalette {
		return switch (theme) {
			// Knight Fortress: parchment paths over warm, dark earth.
			case "arena": new MapPalette(0x654521, 0xDAC8A3, 0xCC9B53, 0x5E4226, 0xA5814C);
			case "catacombs": new MapPalette(0x302A38, 0xAAA3AE, 0x706878, 0x403649, 0x65576E);
			case "prison": new MapPalette(0x332D29, 0xB7A88D, 0x88755A, 0x493C2E, 0x76614C);
			case "tribal": new MapPalette(0x213B25, 0xA7BC78, 0x788044, 0x394923, 0x527144);
			case "dino": new MapPalette(0x29432A, 0xC2BF80, 0x8B9556, 0x46562E, 0x668451);
			case "aztec": new MapPalette(0x293D35, 0xC3BD99, 0x8B9272, 0x454F3B, 0x617A61);
			case "caves": new MapPalette(0x243C53, 0xC3E0E6, 0x7EAFBE, 0x365C77, 0x638CA5);
			case "village": new MapPalette(0x354547, 0xCFD6C5, 0x9A9D7B, 0x515D50, 0x738B83);
			case "temple": new MapPalette(0x30384E, 0xCCD4E1, 0x939FB8, 0x4C5873, 0x707D9B);
			default: new MapPalette(0x654521, 0xDAC8A3, 0xCC9B53, 0x5E4226, 0xA5814C);
		}
	}
}
