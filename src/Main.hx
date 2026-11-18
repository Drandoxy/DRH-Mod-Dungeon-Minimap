package mods.dungeon_minimap;

import mods.api.Mod;
import mods.api.Context;
import mods.api.dungeon.Floor;
import mods.api.Subscription;
import modding.ModSubscription;
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
	var subscriptions:Array<Subscription> = [];
	var coreSubscriptions:Array<ModSubscription> = [];
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
	var waitingRenderers = ["mKillSwitchRenderer", "mVictoryRenderer", "mDefeatRenderer"];
	var mapPlacement:PanelPlacement = new PanelPlacement();
	var resetToast:openfl.display.Sprite;
	var resetToastUntil = 0;

	override public function init(context:Context):Void {
		ctx = context;
		mapPlacement.load(context, "minimap");
		context.settings.button("resetMinimapLayout", "Reset minimap size and location", "Reset").onPress(function() {
			var saved = minimap == null ? mapPlacement.resetGeometry() : minimap.resetGeometry();
			if (saved)
				showResetToast();
		});

		context.keys.action("toggleMap", "Toggle minimap", "Enable or disable the dungeon minimap.", Keyboard.M, true, true).onPress(function() {
			mapPlacement.enabled = !mapPlacement.enabled;
			mapPlacement.save();
			if (mapPlacement.enabled)
				startTracking();
			else
				stopTracking();
		});
		if (mapPlacement.enabled)
			startTracking();
	}

	function startTracking():Void {
		var core = ctx.core;
		subscriptions.push(ctx.onFloorEnter(onFloorEnter));
		subscriptions.push(ctx.onFloorExit(onFloorExit));
		subscriptions.push(ctx.onHeroDespawned(function(hero) {
			if (minimap != null)
				minimap.removeHeroMarker(hero.id);
		}));
		subscriptions.push(ctx.onTownEnter(function() {
			refs.breakableWalls = new Map();
			dungeonStart = -1;
		}));

		coreSubscriptions.push(core.onFieldReceived(function(obj, id, name) {
			if (StringTools.endsWith(name, ".basicCurrency") && Std.isOfType(obj, PlayerGameObjectOwner)) {
				playerOwner = obj;
				onGoldField(obj);
			}
			if (StringTools.endsWith(name, ".floorEnding") || StringTools.endsWith(name, ".dungeonEnding")) {
				var floor = liveFloor();
				if (floor != null && obj == floor.parentArea) {
					endingFloor = floor;
					if (minimap != null)
						minimap.setShown(false);
				}
			}
		}));
		coreSubscriptions.push(core.onObjectReady(function(object) {
			if (Std.isOfType(object, HeroGameObjectOwner))
				refs.localHero = cast object;
			else if (Std.isOfType(object, PlayerGameObjectOwner))
				playerOwner = object;
			else
				trackWall(Std.downcast(object, NPCGameObject));
		}));
		coreSubscriptions.push(core.onObjectGone(function(object) {
			if (object == playerOwner)
				playerOwner = null;
			if (object == refs.localHero)
				refs.localHero = null;
			var npc = Std.downcast(object, NPCGameObject);
			if (npc == null)
				return;
			refs.breakableWalls.remove(npc.id);
			if (minimap != null && npc.actorData != null && npc.isProp)
				minimap.invalidateWalls();
		}));

		var facade = core.facade;
		var objects = facade == null ? null : facade.gameObjectManager;
		if (objects != null) {
			for (hero in ctx.state.heroes) {
				if (!hero.local)
					continue;
				refs.localHero = Std.downcast(objects.getReferenceFromId(hero.id), HeroGameObjectOwner);
				break;
			}
		}
		var floor = liveFloor();
		if (floor != null && floor.remoteActors != null)
			for (actor in floor.remoteActors.toArray())
				trackWall(Std.downcast(actor, NPCGameObject));
		var apiFloor = ctx.state.floor;
		if (apiFloor != null)
			onFloorEnter(apiFloor);
	}

	function stopTracking():Void {
		for (subscription in subscriptions)
			subscription.cancel();
		for (subscription in coreSubscriptions)
			subscription.cancel();
		subscriptions = [];
		coreSubscriptions = [];
		removeMinimap();
		MapPalette.releaseCache();
		refs = new Refs();
		playerOwner = null;
		endingFloor = null;
		dungeonStart = -1;
		gold = 0;
		goldBase = null;
		lastTotal = null;
	}

	function liveFloor():DistributedDungeonFloor {
		var facade = ctx.core.facade;
		var floor = ctx.state.floor;
		var objects = facade == null ? null : facade.gameObjectManager;
		return floor == null || objects == null ? null : Std.downcast(objects.getReferenceFromId(floor.id), DistributedDungeonFloor);
	}

	function updateOverlay(event:Event):Void {
		var now = Lib.getTimer();
		if (minimap != null && minimap.visible && now < nextVisibilityCheck)
			return;
		nextVisibilityCheck = now + 80;
		var facade = ctx.core.facade;
		var floor = liveFloor();
		var shown = facade != null
			&& facade.mainStateMachine != null
			&& facade.mainStateMachine.currentStateName == "RunState"
			&& floor != null
			&& !floor.isDestroyed
			&& floor != endingFloor
			&& minimap != null
			&& !isWaiting(floor)
			&& !settingsOpen();
		if (minimap != null && minimap.visible != shown)
			minimap.setShown(shown);
	}

	function settingsOpen():Bool {
		var facade = ctx.core.facade;
		var nav = facade == null ? null : facade.menuNavigationController;
		return nav != null
			&& (nav.getTopUILayer() == "SETTINGS_MENU"
				|| (nav.layerDepth > 1 && nav.getAllCurrentLayers().indexOf("SETTINGS_MENU, ") >= 0));
	}

	function isWaiting(floor:DistributedDungeonFloor):Bool {
		if (Reflect.field(floor, "mRevealed") == false)
			return true;
		var endingGui = Reflect.field(floor, "mFloorEndingGui");
		if (endingGui == null)
			return false;
		if (Reflect.field(endingGui, "mUpdateCountdownTask") != null)
			return true;
		for (name in waitingRenderers) {
			var renderer:MovieClipRenderController = Reflect.field(endingGui, name);
			if (renderer != null && renderer.isPlaying)
				return true;
		}
		return false;
	}

	function onFloorEnter(floor:Floor):Void {
		if (floor.number == 1 || dungeonStart < 0) {
			dungeonStart = openfl.Lib.getTimer();
			gold = 0;
			goldBase = currentTotal();
		}
		createMinimap();
	}

	function createMinimap():Void {
		if (minimap != null)
			return;
		minimap = new Minimap(ctx, refs, dungeonStart, mapPlacement);
		minimap.setGold(gold);
		ctx.overlay.addChild(minimap);
		ctx.overlay.addEventListener(Event.ENTER_FRAME, updateOverlay);
		updateOverlay(null);
	}

	function trackWall(npc:NPCGameObject):Void {
		if (npc == null || npc.gmNpc == null || npc.actorData == null)
			return;
		var gm = npc.gmNpc;
		if (!gm.IsAttackable || gm.Name == null)
			return;
		var name = gm.Name.toLowerCase();
		if (name.indexOf("cracked wall") >= 0 || (npc.isProp && (name.indexOf("wall") >= 0 || name.indexOf("gate") >= 0)))
			refs.breakableWalls.set(npc.id, npc);
	}

	/** The account balance read on the player object (PlayerGameObjectOwner.basicCurrency), null if unreadable. */
	function readBalance(obj:Dynamic):Null<Int> {
		if (obj == null)
			return null;
		for (n in ["basicCurrency", "mBasicCurrency", "_basicCurrency"]) {
			var value:Null<Int> = null;
			try {
				value = Std.parseInt(Std.string(Reflect.getProperty(obj, n)));
			} catch (_:Dynamic) {}
			if (value != null)
				return value;
		}
		return null;
	}

	/** Best known balance right now: the live field, else the last one reported, else the account's. */
	function currentTotal():Null<Int> {
		var live = readBalance(playerOwner);
		if (live != null)
			return live;
		if (lastTotal != null)
			return lastTotal;
		var acc = ctx.state.account;
		return acc == null ? null : acc.coins;
	}

	/** The server sent PlayerGameObjectOwner.basicCurrency: show what was gained since the dungeon started. */
	function onGoldField(obj:Dynamic):Void {
		var value = readBalance(obj);
		if (value == null)
			return;
		lastTotal = value;
		// Baseline unknown (the balance was not readable at dungeon start): start counting from here
		if (goldBase == null)
			goldBase = value;
		gold = value - goldBase;
		if (minimap != null)
			minimap.setGold(gold);
	}

	function onFloorExit(floor:Floor):Void {
		endingFloor = null;
		removeMinimap();
	}

	function showResetToast():Void {
		clearResetToast();
		var toast = new openfl.display.Sprite();
		toast.mouseEnabled = false;
		toast.mouseChildren = false;
		var label = new openfl.text.TextField();
		label.defaultTextFormat = new openfl.text.TextFormat("_sans", 18, 0xF3DFC1, true);
		label.autoSize = openfl.text.TextFieldAutoSize.LEFT;
		label.text = "Minimap reset to its default size and location.";
		label.selectable = false;
		label.x = 16;
		label.y = 9;
		var w = label.width + 32;
		var h = label.height + 18;
		toast.graphics.lineStyle(1, 0x987E56);
		toast.graphics.beginFill(0x17222B, 0.98);
		toast.graphics.drawRoundRect(0, 0, w, h, 10, 10);
		toast.graphics.endFill();
		toast.addChild(label);
		toast.x = Math.max(0, (ctx.viewWidth - w) / 2);
		toast.y = Math.max(0, ctx.viewHeight - h - 36);
		resetToast = toast;
		resetToastUntil = Lib.getTimer() + 2400;
		ctx.overlay.addChild(toast);
		toast.addEventListener(Event.ENTER_FRAME, expireResetToast);
	}

	function expireResetToast(event:Event):Void {
		if (Lib.getTimer() >= resetToastUntil)
			clearResetToast();
	}

	function clearResetToast():Void {
		if (resetToast == null)
			return;
		resetToast.removeEventListener(Event.ENTER_FRAME, expireResetToast);
		if (resetToast.parent != null)
			resetToast.parent.removeChild(resetToast);
		resetToast = null;
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
		clearResetToast();
		stopTracking();
	}
}
