package mods.dungeon_minimap;

import mods.api.Mod;
import mods.api.Context;
import mods.api.dungeon.Floor;
import mods.api.settings.Flag;
import openfl.ui.Keyboard;
import openfl.events.Event;
import openfl.Lib;
import distributedObjects.NPCGameObject;
import brain.render.MovieClipRenderController;
import distributedObjects.DistributedDungeonFloor;
import distributedObjects.HeroGameObjectOwner;
import distributedObjects.PlayerGameObjectOwner;

class Main extends Mod {
	var ctx:Context;
	var minimap:Minimap;
	var active:Flag;
	var refs:Refs = new Refs();
	var dungeonStart:Int = -1;
	// Gold: the game reports the account balance (basicCurrency), the minimap shows the gain of the run
	var gold = 0; // gained since the dungeon started, kept across floors
	var goldBase:Null<Int> = null; // balance when the dungeon started
	var lastTotal:Null<Int> = null; // last balance the game reported, in town included
	var playerOwner:Dynamic = null; // the local PlayerGameObjectOwner

	// UI choices kept here because each floor creates a new Minimap

	var endingFloor:DistributedDungeonFloor;
	var nextVisibilityCheck = 0;
	var waitingRenderers = ["mStartRenderer", "mKillSwitchRenderer", "mVictoryRenderer", "mDefeatRenderer"];
	var mapPlacement:PanelPlacement = new PanelPlacement();

	override public function init(context:Context):Void {
		ctx = context;
		mapPlacement.load(context, "minimap");
        active = context.settings.flag("active", "Enable minimap", "Draw the dungeon map and its markers.", true);
        active.onChange(setActive);
		ctx.overlay.visible = false;

		context.onFloorEnter(onFloorEnter);
		context.onFloorExit(onFloorExit);
		context.onHeroDespawned(function(hero) {
			if (minimap != null) minimap.removeHeroMarker(hero.id);
		});
		context.keys.action("toggleMap", "Toggle minimap", "Enable or disable the dungeon minimap.", Keyboard.M, true, true)
            .onPress(function() active.value = !active.value);
		context.onTownEnter(function() refs.breakableWalls = new Map());

		var core = context.core;
		core.onFieldReceived(function(obj, id, name) {
			if (StringTools.endsWith(name, ".basicCurrency")) onGoldField(obj);
			if (StringTools.endsWith(name, ".floorEnding") || StringTools.endsWith(name, ".dungeonEnding")) {
				var floor = refs.localHero == null ? null : refs.localHero.distributedDungeonFloor;
				if (floor != null && obj == floor.parentArea) {
					endingFloor = floor;
					ctx.overlay.visible = false;
				}
			}
		});
		core.onObjectReady(function(object) {
			if (Std.isOfType(object, HeroGameObjectOwner)) {
				refs.localHero = cast object;
			} else if (Std.isOfType(object, PlayerGameObjectOwner)) {
				playerOwner = object;
			} else {
                if (active.value) trackWall(Std.downcast(object, NPCGameObject));
			}
		});
		core.onObjectGone(function(object) {
			if (object == playerOwner) playerOwner = null;
			if (object == refs.localHero) refs.localHero = null;
            if (!active.value) return;
			var npc = Std.downcast(object, NPCGameObject);
			if (npc != null) refs.breakableWalls.remove(npc.id);
			if (minimap != null && npc != null && npc.actorData != null && npc.isProp) minimap.invalidateWalls();
		});
	}

	function updateOverlay(event:Event):Void {
		var now = Lib.getTimer();
		if (now < nextVisibilityCheck) return;
		nextVisibilityCheck = now + 80;
		var facade = ctx.core.facade;
		var floor = refs.localHero == null ? null : refs.localHero.distributedDungeonFloor;
		var shown = facade != null && facade.mainStateMachine != null
			&& facade.mainStateMachine.currentStateName == "RunState"
			&& floor != null && !floor.isDestroyed && floor != endingFloor
			&& minimap != null && !isWaiting(floor);
		if (ctx.overlay.visible != shown) ctx.overlay.visible = shown;
	}

	function isWaiting(floor:DistributedDungeonFloor):Bool {
		if (Reflect.field(floor, "mRevealed") == false) return true;
		var endingGui = Reflect.field(floor, "mFloorEndingGui");
		if (endingGui == null) return false;
		if (Reflect.field(endingGui, "mUpdateCountdownTask") != null) return true;
		for (name in waitingRenderers) {
			var renderer:MovieClipRenderController = Reflect.field(endingGui, name);
			if (renderer != null && renderer.isPlaying) return true;
		}
		return false;
	}

	function onFloorEnter(floor:Floor):Void {
		if (floor.number == 1 || dungeonStart < 0) {
			dungeonStart = openfl.Lib.getTimer();
			gold = 0;
			goldBase = currentTotal();
		}
        if (active.value) createMinimap();
    }

    function createMinimap():Void {
        if (minimap != null) return;
        minimap = new Minimap(ctx, refs, dungeonStart, mapPlacement);
        minimap.setGold(gold);
        ctx.overlay.addChild(minimap);
        ctx.overlay.addEventListener(Event.ENTER_FRAME, updateOverlay);
    }

    function trackWall(npc:NPCGameObject):Void {
        if (npc == null || npc.gmNpc == null || npc.actorData == null) return;
        var gm = npc.gmNpc;
        if (!gm.IsAttackable || gm.Name == null) return;
        var name = gm.Name.toLowerCase();
        if (name.indexOf("cracked wall") >= 0 ||
            (npc.isProp && (name.indexOf("wall") >= 0 || name.indexOf("gate") >= 0)))
            refs.breakableWalls.set(npc.id, npc);
    }

	/** The account balance read on the player object (PlayerGameObjectOwner.basicCurrency), null if unreadable. */
	function readBalance(obj:Dynamic):Null<Int> {
		if (obj == null) return null;
		for (n in ["basicCurrency", "mBasicCurrency", "_basicCurrency"]) {
			var value:Null<Int> = null;
			try {
				value = Std.parseInt(Std.string(Reflect.getProperty(obj, n)));
			} catch (_:Dynamic) {}
			if (value != null) return value;
		}
		return null;
	}

	/** Best known balance right now: the live field, else the last one reported, else the account's. */
	function currentTotal():Null<Int> {
		var live = readBalance(playerOwner);
		if (live != null) return live;
		if (lastTotal != null) return lastTotal;
		var acc = ctx.state.account;
		return acc == null ? null : acc.coins;
	}

	/** The server sent PlayerGameObjectOwner.basicCurrency: show what was gained since the dungeon started. */
	function onGoldField(obj:Dynamic):Void {
		var value = readBalance(obj);
		if (value == null) return;
		lastTotal = value;
		// Baseline unknown (the balance was not readable at dungeon start): start counting from here
		if (goldBase == null) goldBase = value;
		gold = value - goldBase;
		if (minimap != null) minimap.setGold(gold);
	}

	function onFloorExit(floor:Floor):Void {
		ctx.overlay.visible = false;
		endingFloor = null;
		removeMinimap();
	}

    function setActive(enabled:Bool):Void {
        if (!enabled) {
            ctx.overlay.visible = false;
            removeMinimap();
            refs.breakableWalls = new Map();
            return;
        }
        var floor = refs.localHero == null ? null : refs.localHero.distributedDungeonFloor;
        if (floor == null || ctx.state.floor == null) return;
        if (floor.remoteActors != null)
            for (actor in floor.remoteActors.toArray()) trackWall(Std.downcast(actor, NPCGameObject));
        if (dungeonStart < 0) dungeonStart = Lib.getTimer();
        createMinimap();
    }

	function removeMinimap():Void {
        ctx.overlay.removeEventListener(Event.ENTER_FRAME, updateOverlay);
		if (minimap != null) {
			minimap.destroy();
			ctx.overlay.removeChild(minimap);
			minimap = null;
		}
	}

	override public function dispose():Void {
		ctx.overlay.removeEventListener(Event.ENTER_FRAME, updateOverlay);
		removeMinimap();
	}
}
