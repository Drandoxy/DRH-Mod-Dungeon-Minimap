package mods.dungeon_minimap;

/** Gate lookup and color convention adapted from Xk's Minimap (GPLv3). */
class GateColors {
    static inline final ORANGE = 0xF0A030;
    static inline final PURPLE = 0x9B59D0;
    static inline final CYAN = 0x2EC4D6;
    static inline final GREEN = 0x3FB950;
    static inline final RED = 0xD93636;
    public static inline final UNKNOWN = 0x8A8F98;

    public static function isGateColor(color:Int):Bool {
        return color == ORANGE || color == PURPLE || color == CYAN ||
            color == GREEN || color == RED || color == UNKNOWN;
    }

    public static function forTile(tile:Dynamic, mode:String):Int {
        if (mode == "BOSS_CLEAR") return PURPLE;
        if (tile == null) return UNKNOWN;
        var actors:Dynamic = Reflect.getProperty(tile, "NPCGameObjects");
        if (mode == "PLATE_KILLS_TRAP") return PURPLE;
        if (actors == null || mode == "NONE") return UNKNOWN;
        var found = false;
        var closed = false;
        var unreadable = false;
        var breakable = false;
        var entries:Array<Dynamic> = [];
        if (Std.isOfType(actors, Array)) {
            entries = cast actors;
        } else {
            var enumerate = Reflect.field(actors, "iterator");
            if (enumerate == null) return UNKNOWN;
            var iterator:Dynamic = Reflect.callMethod(actors, enumerate, []);
            while (iterator.hasNext()) entries.push(iterator.next());
        }
        for (actor in entries) {
            var type = Std.parseInt(Std.string(Reflect.getProperty(actor, "type")));
            if (type == null || type < 2000000 || type >= 3000000) continue;
            var suffix = type % 10000;
            var triggered = Reflect.getProperty(actor, "triggerState");
            if (mode == "PLATE_TRAP" && suffix == 301)
                return triggered == true ? GREEN : (triggered == false ? ORANGE : UNKNOWN);
            var gm = Reflect.getProperty(actor, "gmNpc");
            var constant = gm == null ? null : Reflect.field(gm, "Constant");
            var isExit = constant != null && Std.string(constant).indexOf("EXIT_GATE") >= 0;
            if (suffix != 101 && suffix != 201 && !isExit) continue;
            found = true;
            if (triggered == false) continue;
            if (triggered != true) {
                unreadable = true;
                continue;
            }
            closed = true;
            if (Reflect.getProperty(actor, "isAttackable") == true) breakable = true;
        }
        if (breakable) return CYAN;
        if (closed || mode == "PLATE_TRAP") {
            return switch (mode) {
                case "PLATE", "PLATE_TRAP": ORANGE;
                case "KILLS", "PLATE_KILLS": PURPLE;
                default: RED;
            };
        }
        if (found && !unreadable) return GREEN;
        return UNKNOWN;
    }
}
