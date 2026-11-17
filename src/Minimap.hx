package mods.dungeon_minimap;

import mods.api.Context;
import brain.assetRepository.AssetLoadingComponent;
import brain.assetRepository.SwfAsset;
import facade.DBFacade;
import gameMasterDictionary.GMChest;
import openfl.display.MovieClip;
import openfl.geom.Matrix;
import box2D.collision.shapes.B2PolygonShape;
import box2D.common.math.B2Vec2;
import box2D.dynamics.B2Body;
import mods.api.Dictionaries;
import openfl.geom.Rectangle;
import openfl.filters.GlowFilter;
import doobers.DooberGameObject;
import openfl.display.Sprite;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.events.Event;
import openfl.geom.Vector3D;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;
import openfl.Lib;
import distributedObjects.DistributedDungeonFloor;
import distributedObjects.NPCGameObject;

class Minimap extends Sprite {
	// Layout
	static inline var DEFAULT_MAP_W = PanelPlacement.DEFAULT_MAP_WIDTH;
	static inline var DEFAULT_MAP_H = PanelPlacement.DEFAULT_MAP_HEIGHT;
	static inline var HEADER_H = 28.;
	static inline var FOOTER_H = 28.;
	static inline var PAD = 6.;
	static inline var PANEL_W = DEFAULT_MAP_W + PAD * 2;
	static inline var PANEL_H = DEFAULT_MAP_H + HEADER_H + FOOTER_H + PAD * 2;
	static inline var TILE_SIZE = 900.;
	public static inline final DEFAULT_TOP = 110.;
	public static inline final DEFAULT_BOTTOM = DEFAULT_TOP + PANEL_H;
	static inline final LOCAL_HERO_RADIUS = 7.;
	static inline final CHEST_SIZE = LOCAL_HERO_RADIUS * 2.;
	static inline final MAIN_WALL_LENGTH = 190.;
	static inline final LARGE_BLOCK_LENGTH = 320.;

	// Refresh rates
	static inline final MARKER_REFRESH_MS = 120;
	static inline final WALL_REFRESH_MS = 1000;

	var ctx:Context;
	var refs:Refs;
	var startTime:Int;

	var viewport:Sprite = new Sprite();
	var mapContent:Sprite = new Sprite();
	var zoomLevel = 1.0;
	var placement:PanelPlacement;
	var panStage:openfl.display.Stage;
	var panMouseX = 0.0;
	var panMouseY = 0.0;
	var resumeFollowAt = 0;
	var map:Sprite = new Sprite();
	var clippedExit:Bitmap;
	var monsterLayer:Sprite = new Sprite();
	var breakableLayer:Sprite = new Sprite();
	var chestLayer:Sprite = new Sprite();
	var chestArt:Map<UInt, BitmapData> = new Map();
	var chestMarkers:Map<UInt, Sprite> = new Map();
	var wallLayer:Sprite = new Sprite();
	var roomMask:Sprite = new Sprite();
	var markersByHero:Map<UInt, Sprite> = new Map();

	var timerLabel:TextField;
	var floorLabel:TextField;
	var goldLabel:TextField;
	var xpLabel:TextField;
	var assets:AssetLoadingComponent;
    var counterArt:Array<BitmapData> = [];
    var destroyed = false;


	var exitModes:Map<String, String> = new Map();
    var exitTiles:Map<String, String> = new Map();
    var exitColors:Map<String, Int> = new Map();
    var exitPositions:Array<Vector3D> = [];

	// Drawing state
	var ready = false;
	var drawnTileSignature = "";
	var palette = MapPalette.forTheme("arena");
	var minX = 0.;
	var minY = 0.;
	var scale = 1.;
	var markerScale = 1.;
	var offX = 0.;
	var offY = 0.;

	// Redraw triggers
	var drawnFloor:DistributedDungeonFloor;
	var nextHeroRefresh = 0;
	var nextMarkerRefresh = 0;
	var nextWallRefresh = 0;
	var nextHeaderRefresh = 0;

	var controls:PanelControls;

    var mapWidth = DEFAULT_MAP_W;
    var mapHeight = DEFAULT_MAP_H;
    var footer = new Sprite();
    var zoomOut:Sprite;
    var zoomIn:Sprite;
    var lockButton = new Sprite();
    var gateButton=new Sprite();
    var gateLabel:TextField;
    var gateDetailsHeight=0.;
    var gateCodes=false;
    var buttons:Array<Sprite>=[];
    var exitLayer = new Sprite();
    var exitMarkers = new Sprite();
    var clipAfter = -1;
    var redrawAfter = 0;

	public function new(ctx:Context, refs:Refs, startTime:Int, placement:PanelPlacement) {
		super();
		this.ctx = ctx;
		this.placement = placement;
		zoomLevel = placement.zoom;
		this.refs = refs;
		this.startTime = startTime;
		controls = new PanelControls(this, ctx, placement, PANEL_W, PANEL_H, DEFAULT_TOP);

		controls.dragHeaderHeight = HEADER_H;
        controls.resizeFree = resizePanel;
		mouseChildren = true;
		viewport.x = PAD;
		viewport.y = HEADER_H + PAD;
		viewport.scrollRect = new Rectangle(0, 0, mapWidth, mapHeight);
		viewport.mouseEnabled = true;
		viewport.addEventListener(openfl.events.MouseEvent.MOUSE_DOWN, startPan);
		viewport.mouseChildren = false;
		viewport.addChild(mapContent);
		addChild(viewport);
		mapContent.x = -PAD;
		mapContent.y = -HEADER_H - PAD;


		map.x = PAD;
		map.y = HEADER_H + PAD;
		mapContent.addChild(map);
        map.addChild(exitLayer);
		wallLayer.x = map.x;
		wallLayer.y = map.y;
		wallLayer.scrollRect = new Rectangle(0, 0, mapWidth, mapHeight);
		mapContent.addChild(wallLayer);
        exitMarkers.x = map.x;
        exitMarkers.y = map.y;
        mapContent.addChild(exitMarkers);
		roomMask.x = map.x;
		roomMask.y = map.y;
		mapContent.addChild(roomMask);
		wallLayer.mask = roomMask;

		mapContent.addChild(monsterLayer);
		breakableLayer.x = map.x;
		breakableLayer.y = map.y;
		breakableLayer.scrollRect = new Rectangle(0, 0, mapWidth, mapHeight);
		breakableLayer.filters = [new GlowFilter(0xD488FF, 0.95, 5, 5, 2.5)];
		mapContent.addChild(breakableLayer);
		mapContent.addChild(chestLayer);



		timerLabel = label(new TextFormat("_sans", 11, 0xF3DFC1, true), PAD, 6, 80);
		var floorFormat = new TextFormat("_sans", 11, 0xF3DFC1, true);
		floorFormat.align = TextFormatAlign.RIGHT;
		floorLabel = label(floorFormat, PANEL_W - PAD - 75, 6, 75);
		var footerTop = HEADER_H + DEFAULT_MAP_H + PAD;
        addChild(footer);
		var counterTop = footerTop + (FOOTER_H + PAD - 18) / 2;
		var xpLeft = PAD + 48;
		assets = new AssetLoadingComponent(ctx.core.facade);
		addLucideCounter("coins",PAD,footerTop+9,0xFFD76A);
		addLucideCounter("sparkles",xpLeft,footerTop+9,0x58C9FF);
		goldLabel = label(new TextFormat("Arial", 12, 0xFFD700, true), PAD + 18, counterTop, 28);
		xpLabel = label(new TextFormat("Arial", 12, 0x58C9FF, true), xpLeft + 18, counterTop, 24);
		footer.addChild(goldLabel);
        footer.addChild(xpLabel);
		goldLabel.text = "0";
		xpLabel.text = "0";
		zoomOut = addZoomButton(116, footerTop + 6, false);
		zoomIn = addZoomButton(134, footerTop + 6, true);
        lockButton=makeButton("lock-keyhole",footerTop+7,toggleAspectLock);
        gateButton=makeButton("castle",footerTop+7,function(event:openfl.events.MouseEvent){
            event.stopPropagation();gateCodes=!gateCodes;drawButton(gateButton,"castle",gateCodes);refreshGateDetails();
        });
        gateLabel=label(new TextFormat("_sans",10,0xDAEDD8,true),PAD,footerTop+FOOTER_H+PAD,DEFAULT_MAP_W);
        gateLabel.multiline=true;gateLabel.wordWrap=true;gateLabel.visible=false;footer.addChild(gateLabel);
        drawAspectLock();
        resizePanel(placement.mapWidth + PAD * 2, placement.mapHeight + PANEL_H - DEFAULT_MAP_H);
        for (id in 60001...60008) loadChestIcon(id);
		loadExitModes();
		controls.layout();
		addEventListener(Event.ENTER_FRAME, onFrame);
	}

    function addLucideCounter(name:String,x:Float,y:Float,color:Int):Void{
        var icon=new Sprite();MapIcons.draw(icon,name,16,color);icon.x=x;icon.y=y;icon.mouseEnabled=false;footer.addChild(icon);
    }

    function drawButton(button:Sprite,name:String,active:Bool,hover:Bool=false):Void{
        var g=button.graphics;g.clear();g.lineStyle(1,active?0x82DE91:0x536977);
        g.beginFill(active?0xA5E8AD:(hover?0x3E5665:0x293D49));g.drawRoundRect(0,0,18,20,6,6);g.endFill();
        var icon:Sprite=cast button.getChildAt(0);MapIcons.draw(icon,name,14,active?0x15572C:0xE8F0F5);icon.x=2;icon.y=3;
    }

    function makeButton(name:String,y:Float,action:openfl.events.MouseEvent->Void):Sprite{
        var button=new Sprite();button.buttonMode=true;button.mouseChildren=false;button.y=y;
        var icon=new Sprite();icon.mouseEnabled=false;button.addChild(icon);drawButton(button,name,false);
        button.addEventListener(openfl.events.MouseEvent.MOUSE_DOWN,action);
        button.addEventListener(openfl.events.MouseEvent.ROLL_OVER,function(_){drawButton(button,button==lockButton?(placement.aspectLocked?"lock-keyhole":"lock-keyhole-open"):name,button==gateButton&&gateCodes,true);});
        button.addEventListener(openfl.events.MouseEvent.ROLL_OUT,function(_){drawButton(button,button==lockButton?(placement.aspectLocked?"lock-keyhole":"lock-keyhole-open"):name,button==gateButton&&gateCodes);});
        buttons.push(button);footer.addChild(button);return button;
    }

    function addZoomButton(x:Float,y:Float,increase:Bool):Sprite{
        return makeButton(increase?"zoom-in":"zoom-out",y,function(event:openfl.events.MouseEvent){
            event.stopPropagation();resumeFollowAt=0;zoomLevel=Math.max(1,Math.min(3,zoomLevel+(increase ? 0.125 : -0.125)));
            placement.zoom=zoomLevel;placement.save();updateZoom();
        });
    }

    function refreshGateDetails():Void{
        if(gateLabel==null)return;
        gateLabel.visible=gateCodes;
        var content:Array<String>=[];
        if(gateCodes){
            var floor=currentFloor();var grid=floor==null?null:floor.tileGrid;
            var apiFloor=ctx.state.floor;
            for(position in exitPositions){
                var key=posKey(position.x,position.y);var id="unknown";
                if(apiFloor!=null)for(t in apiFloor.tiles)if(t.x==position.x&&t.y==position.y){id=t.id;break;}
                var tile:Dynamic=null;try{if(grid!=null)tile=grid.getTileAtPosition(position);}catch(_:Dynamic){}
                var mode=exitTiles.get(key);var color=exitColors.get(key);
                content.push(GateDetails.describe(id,mode,color,tile));
            }
            if(content.length==0)content.push("Gate data not available yet.");
        }
        var text=content.join("\n\n");var changed=gateLabel.text!=text;gateLabel.width=mapWidth;
        if(changed)gateLabel.text=text;
        var height=gateCodes?Math.max(24,gateLabel.textHeight+8):0.;
        gateLabel.height=height;
        if(height!=gateDetailsHeight){gateDetailsHeight=height;resizePanel(mapWidth+PAD*2,mapHeight+(PANEL_H-DEFAULT_MAP_H)+height);controls.layout();}
    }

    function startPan(event:openfl.events.MouseEvent):Void {
        event.stopPropagation();
        if (zoomLevel <= 1 || stage == null) return;
        panStage = stage;
        panMouseX = mouseX;
        panMouseY = mouseY;
        panStage.addEventListener(openfl.events.MouseEvent.MOUSE_MOVE, movePan);
        panStage.addEventListener(openfl.events.MouseEvent.MOUSE_UP, endPan);
        panStage.addEventListener(Event.DEACTIVATE, endPan);
    }

    function movePan(event:openfl.events.MouseEvent):Void {
        mapContent.x += mouseX - panMouseX;
        mapContent.y += mouseY - panMouseY;
        panMouseX = mouseX;
        panMouseY = mouseY;
        // Keep the map field intersecting the viewport while inspecting its edges.
        clampMapView();
        event.stopPropagation();
    }

    function clampMapView():Void {
        mapContent.x = Math.max(mapWidth - (PAD + mapWidth) * zoomLevel,
            Math.min(-PAD * zoomLevel, mapContent.x));
        mapContent.y = Math.max(mapHeight - (HEADER_H + PAD + mapHeight) * zoomLevel,
            Math.min(-(HEADER_H + PAD) * zoomLevel, mapContent.y));
    }

    function endPan(event:Event):Void {
        if (panStage == null) return;
        panStage.removeEventListener(openfl.events.MouseEvent.MOUSE_MOVE, movePan);
        panStage.removeEventListener(openfl.events.MouseEvent.MOUSE_UP, endPan);
        panStage.removeEventListener(Event.DEACTIVATE, endPan);
        panStage = null;
        resumeFollowAt = Lib.getTimer() + 4000;
    }

    function updateZoom():Void {
        mapContent.scaleX = mapContent.scaleY = zoomLevel;
        if (zoomLevel == 1) {
            mapContent.x = -PAD;
            mapContent.y = -HEADER_H - PAD;
            return;
        }
        if (panStage != null || Lib.getTimer() < resumeFollowAt) return;
        var hero = refs.localHero;
        if (hero == null || !ready) return;
        var x = PAD + offX + (hero.positionX - minX) * scale;
        var y = HEADER_H + PAD + offY + (hero.positionY - minY) * scale;
        mapContent.x = mapWidth / 2 - x * zoomLevel;
        mapContent.y = mapHeight / 2 - y * zoomLevel;
        clampMapView();
    }

    function addCounterIcon(path:String, symbol:String, x:Float, footerTop:Float, size:Float):Void {
        loadIcon(path, symbol, function(art) {
            counterArt.push(art);
            var icon = new Bitmap(art);
            icon.smoothing = true;
            icon.scaleX = icon.scaleY = size / Math.max(art.width, art.height);
            icon.x = x + (19 - icon.width) / 2;
            icon.y = footerTop + (FOOTER_H + PAD - icon.height) / 2;
            footer.addChild(icon);
        });
    }

    function loadChestIcon(id:UInt):Void {
        var chest:GMChest = cast ctx.core.facade.gameMaster.chestsById.itemFor(id);
        if (chest == null) return;
        loadIcon(chest.IconSwf, chest.IconName, function(art) {
            chestArt.set(id, art);
            nextMarkerRefresh = 0;
        });
    }

    // Capture the game's own icon once so markers do not run SWF timelines.
    function loadIcon(path:String, symbol:String, ready:BitmapData->Void):Void {
        if (path == null || path == "" || symbol == null || symbol == "") return;
        assets.getSwfAsset(DBFacade.buildFullDownloadPath(path), function(asset:SwfAsset) {
            if (destroyed || asset == null) return;
            try {
                var clip:MovieClip = cast asset.instantiateRuntimeSymbol(symbol, []);
                if (clip == null) return;
                clip.stop();
                var bounds = clip.getBounds(clip);
                var longest = Math.max(bounds.width, bounds.height);
                if (!(longest > 0)) return;
                var factor = 96 / longest;
                var art = new BitmapData(Std.int(Math.ceil(bounds.width * factor)) + 2,
                    Std.int(Math.ceil(bounds.height * factor)) + 2, true, 0);
                try {
                    art.draw(clip, new Matrix(factor, 0, 0, factor,
                        1 - bounds.x * factor, 1 - bounds.y * factor), null, null, null, true);
                } catch (error:Dynamic) {
                    art.dispose();
                    throw error;
                }
                var visibleBounds = art.getColorBoundsRect(0xFF000000, 0, false);
                if (visibleBounds.isEmpty()) {
                    art.dispose();
                    return;
                }
                var trimmed = new BitmapData(Std.int(visibleBounds.width), Std.int(visibleBounds.height), true, 0);
                trimmed.copyPixels(art, visibleBounds, new openfl.geom.Point());
                art.dispose();
                ready(trimmed);
            } catch (error:Dynamic) {
                ctx.log("Could not load minimap icon " + symbol + ": " + Std.string(error));
            }
        });
    }

    static function chestGlow(id:UInt):Int {
        return switch (id) {
            case 60001: 0xEFB150;
            case 60002: 0x58B8FF;
            case 60003: 0xFFC23A;
            case 60004: 0xC485FF;
            case 60005: 0xE8EFF8;
            default: 0xFFDA5A;
        };
    }

    public function resetGeometry():Bool {
        controls.finish(null);
        endPan(null);
        resumeFollowAt = 0;
        var saved = placement.resetGeometry();
        resizePanel(PANEL_W, PANEL_H+gateDetailsHeight);
        controls.layout();
        return saved;
    }

    function resizePanel(width:Float, height:Float):Void {
        var fixedHeight = PANEL_H - DEFAULT_MAP_H + gateDetailsHeight;
        mapWidth = Math.max(DEFAULT_MAP_W, width - PAD * 2);
        mapHeight = Math.max(70, height - fixedHeight);
        placement.mapWidth = mapWidth;
        placement.mapHeight = mapHeight;
        var panelWidth = mapWidth + PAD * 2;
        var panelHeight = mapHeight + fixedHeight;
        controls.setSize(panelWidth, panelHeight);
        viewport.scrollRect = new Rectangle(0, 0, mapWidth, mapHeight);
        wallLayer.scrollRect = new Rectangle(0, 0, mapWidth, mapHeight);
        breakableLayer.scrollRect = new Rectangle(0, 0, mapWidth, mapHeight);
        floorLabel.x = panelWidth - PAD - 75;
        footer.y = mapHeight - DEFAULT_MAP_H;
        gateButton.x=panelWidth-86;
        zoomOut.x = panelWidth - 66;
        zoomIn.x = panelWidth - 46;
        lockButton.x = panelWidth - 26;
        if(gateLabel!=null)gateLabel.width=mapWidth;
        graphics.clear();
		// Panel background and separators
		graphics.beginFill(0x17222B, 0.98);
		graphics.lineStyle(1.5, 0x987E56, 0.96);
		graphics.drawRoundRect(0, 0, panelWidth, panelHeight, 10, 10);
		graphics.endFill();
		graphics.lineStyle(0, 0, 0);
		graphics.beginFill(0x212D35, 1);
		graphics.drawRoundRect(5, 5, panelWidth - 10, HEADER_H - 8, 5, 5);
		graphics.endFill();
		graphics.lineStyle(1, 0x6B5F4D, 0.9);
		graphics.beginFill(0x344959, 1);
		graphics.drawRoundRect(PAD, HEADER_H + PAD, mapWidth, mapHeight, 6, 6);
		graphics.endFill();
		graphics.lineStyle(0.85, 0x6B5F4D, 0.9);
		graphics.moveTo(6, HEADER_H);
		graphics.lineTo(panelWidth - 6, HEADER_H);
		graphics.moveTo(6, HEADER_H + mapHeight + PAD);
		graphics.lineTo(panelWidth - 6, HEADER_H + mapHeight + PAD);

        ready = false;
        redrawAfter = drawnFloor == null ? 0 : Lib.getTimer() + 100;
    }

    function toggleAspectLock(event:openfl.events.MouseEvent):Void {
        event.stopPropagation();
        placement.aspectLocked = !placement.aspectLocked;
        drawAspectLock();
        placement.save();
    }

    function drawAspectLock():Void {
        drawButton(lockButton,placement.aspectLocked?"lock-keyhole":"lock-keyhole-open",false);
    }

	function label(fmt:TextFormat, x:Float, y:Float, w:Float):TextField {
		var t = new TextField();
		t.defaultTextFormat = fmt;
		t.selectable = false;
		t.mouseEnabled = false;
		t.width = w;
		t.height = 20;
		t.x = x;
		t.y = y;
		addChild(t);
		return t;
	}

	/** Called by Main each time the game reports the gold (and when a new floor creates this minimap). */
	public function setGold(amount:Int):Void {
		var text = formatCounter(amount);
		if (goldLabel.text != text) goldLabel.text = text;
	}

	static function formatCounter(amount:Float):String {
		if (Math.abs(amount) < 10000) return Std.string(amount);
		var sign = amount < 0 ? "-" : "";
		return sign + Math.floor(Math.abs(amount) / 1000) + "k";
	}

	public function setShown(shown:Bool):Void {
		visible = shown;
		if (!shown) { controls.finish(null); endPan(null); }
	}

	/** The floor the local hero is on (same path as the original AS3 code). */
	function currentFloor():DistributedDungeonFloor {
        var hero = refs.localHero;
        if (hero != null && hero.distributedDungeonFloor != null) return hero.distributedDungeonFloor;
        var floor = ctx.state.floor;
        var facade = ctx.core.facade;
        var objects = facade == null ? null : facade.gameObjectManager;
        return floor == null || objects == null ? null
            : Std.downcast(objects.getReferenceFromId(floor.id), DistributedDungeonFloor);
	}

	/** Tile corners of the floor, without filler tiles. */
	function getTilePositions():Array<Vector3D> {
		var floor = ctx.state.floor;
		if (floor == null) return null;
		var out:Array<Vector3D> = [];
		for (t in floor.tiles)
			if (t.category != "FILLER_TILE") out.push(new Vector3D(t.x, t.y));
		return out;
	}

    function tileSignature():String {
        var floor = ctx.state.floor;
        if (floor == null) return "";
        var parts:Array<String> = [];
        for (tile in floor.tiles)
            if (tile.category != "FILLER_TILE") parts.push(tile.id + ":" + tile.x + ":" + tile.y);
        return parts.join(";");
    }

	inline function posKey(x:Float, y:Float):String
		return Std.int(x) + "," + Std.int(y);

    function loadExitModes():Void {
        try {
            var data = haxe.Json.parse(sys.io.File.getContent(ctx.resources + "/exit_modes.json"));
            for (id in Reflect.fields(data)) exitModes.set(id, Std.string(Reflect.field(data, id)));
        } catch (error:Dynamic) {
            ctx.log("Could not read exit gate modes: " + Std.string(error));
        }
    }

    function refreshExits():Void {
        exitTiles = new Map();
        exitColors = new Map();
        exitPositions = [];
        var floor = ctx.state.floor;
        if (floor == null) return;
        for (tile in floor.tiles) {
            if (tile.category == "FILLER_TILE") continue;
            if (tile.category != "EXIT_TILE" && !exitModes.exists(tile.id)) continue;
            exitTiles.set(posKey(tile.x, tile.y), exitModes.get(tile.id));
            exitPositions.push(new Vector3D(tile.x, tile.y));
        }
        refreshExitColors();
    }

    function refreshExitColors():Bool {
        var changed = false;
        var floor = currentFloor();
        var grid = floor == null ? null : floor.tileGrid;
        for (position in exitPositions) {
            var key = posKey(position.x, position.y);
            var color = GateColors.UNKNOWN;
            try {
                var tile = grid == null ? null : grid.getTileAtPosition(position);
                color = GateColors.forTile(tile, exitTiles.get(key));
            } catch (_:Dynamic) {
                // Keep the exit visible while its actors are unavailable.
            }
            if (exitColors.get(key) != color) {
                exitColors.set(key, color);
                changed = true;
            }
        }
        return changed;
    }

	function updateMonsters():Void {
		monsterLayer.graphics.clear();
		monsterLayer.graphics.lineStyle(0.35, 0x742C31, 0.8);
		monsterLayer.graphics.beginFill(0xEF5657, 0.94);
		var floor = ctx.state.floor;
		if (floor != null)
			for (m in floor.monsters)
				monsterLayer.graphics.drawCircle(PAD + offX + (m.x - minX) * scale, HEADER_H + PAD + offY + (m.y - minY) * scale, 1.8);
		monsterLayer.graphics.endFill();
	}

	public function invalidateWalls():Void {
		nextWallRefresh = 0;
	}

	function onFrame(_):Void {
		if (!visible || !ctx.overlay.visible) return;
		var now = Lib.getTimer();
		if (now < nextHeroRefresh) return;
		nextHeroRefresh = now + 33;
		controls.layout();

		var floor = currentFloor();
		if (floor != drawnFloor) ready = false;
		if (now >= nextHeaderRefresh) {
			nextHeaderRefresh = now + 250;
			updateTimer();
			if (floor != null) {
				var max = floor.getMaxFloorNum();
				var label = "Floor " + floor.getCurrentFloorNum() + (max > 1 ? "/" + max : "");
				if (floorLabel.text != label) floorLabel.text = label;
				var area = floor.parentArea;
				if (area != null) {
					var xp = formatCounter(area.expCollected);
					if (xpLabel.text != xp) xpLabel.text = xp;
				}
			}

		}
        if (!ready && now >= redrawAfter) drawDungeonIfReady();
		if (!ready) return;
        if (clipAfter >= 0 && now >= clipAfter && floor != null && floor.box2DWorld != null) {
            clipAfter = -1;
            updateWalls();
            clipExitToWalls();
        }

		updateZoom();
		updateHeroMarkers();
		if (now >= nextMarkerRefresh) {
			nextMarkerRefresh = now + MARKER_REFRESH_MS;
			updateMonsters();
			updateBreakables();
			updateChests();
		}
		if (now >= nextWallRefresh) {
			nextWallRefresh = now + WALL_REFRESH_MS;
			if (tileSignature() != drawnTileSignature) drawDungeonIfReady();
            else {
                if (refreshExitColors()) drawExitTiles();
                updateWalls();
            }
            if(gateCodes)refreshGateDetails();
		}
	}

	function updateBreakables():Void {
		var pen = breakableLayer.graphics;
		pen.clear();
		var floor = currentFloor();
		if (floor == null) return;

		for (npc in refs.breakableWalls) {
			if (npc.distributedDungeonFloor != floor || npc.isDestroyed || !npc.hasPosition
				|| npc.hitPoints == 0 || !npc.isAttackable) continue;
			if (drawBreakableWalls(npc)) continue;

			var x = offX + (npc.positionX - minX) * scale;
			var y = offY + (npc.positionY - minY) * scale;
			pen.lineStyle(1.65, 0xF4D8FF);
			pen.beginFill(0xB249E2);
			pen.drawRect(x - 5, y - 2.5, 10, 5);
			pen.endFill();
			drawCrack(x, y, 1, 0, 4, 2);
		}
	}

	function drawBreakableWalls(npc:NPCGameObject):Bool {
		var drawn = false;
		var colliders = npc.navCollisions;
		if (colliders == null) return false;
		var pen = breakableLayer.graphics;
		for (i in 0...colliders.length) {
			var collider = colliders[i];
			if (collider == null || !collider.active) continue;
			var polygon = Std.downcast(collider.getShape(), B2PolygonShape);
			if (polygon == null || polygon.GetVertexCount() < 3) continue;
			var body = collider.getBody();
			var vertices = polygon.GetVertices();
			var count = polygon.GetVertexCount();
			var points = new Array<{x:Float, y:Float}>();
			var cx = 0.;
			var cy = 0.;
			for (j in 0...count) {
				var point = body.GetWorldPoint(cast vertices[j]);
				var x = offX + (point.x * 50 - minX) * scale;
				var y = offY + (point.y * 50 - minY) * scale;
				points.push({x: x, y: y});
				cx += x / count;
				cy += y / count;
			}

			pen.lineStyle(1.65, 0xF4D8FF);
			pen.beginFill(0xB249E2);
			pen.moveTo(points[0].x, points[0].y);
			for (j in 1...count) pen.lineTo(points[j].x, points[j].y);
			pen.lineTo(points[0].x, points[0].y);
			pen.endFill();

			var longest = 0.;
			var shortest = Math.POSITIVE_INFINITY;
			var vx = 1.;
			var vy = 0.;
			for (j in 0...count) {
				var next = points[(j + 1) % count];
				var dx = next.x - points[j].x;
				var dy = next.y - points[j].y;
				var length = Math.sqrt(dx * dx + dy * dy);
				if (length <= 0) continue;
				shortest = Math.min(shortest, length);
				if (length > longest) {
					longest = length;
					vx = dx / length;
					vy = dy / length;
				}
			}
			if (longest > 0) drawCrack(cx, cy, vx, vy, longest * 0.42, shortest * 0.36);
			drawn = true;
		}
		return drawn;
	}

	function drawCrack(x:Float, y:Float, vx:Float, vy:Float, length:Float, width:Float):Void {
		var pen = breakableLayer.graphics;
		pen.lineStyle(1.45, 0x35134C);
		pen.moveTo(x - vx * length + vy * width, y - vy * length - vx * width);
		pen.lineTo(x - vx * length * 0.36 - vy * width, y - vy * length * 0.36 + vx * width);
		pen.lineTo(x + vx * length * 0.17 + vy * width, y + vy * length * 0.17 - vx * width);
		pen.lineTo(x + vx * length - vy * width * 0.5, y + vy * length + vx * width * 0.5);
	}

	function updateWalls():Void {
		var pen = wallLayer.graphics;
		pen.clear();
		var floor = currentFloor();
		if (floor == null || floor.box2DWorld == null) return;

		var body = floor.box2DWorld.GetBodyList();
		while (body != null) {
			if (body.IsActive() && !isTrapBody(body, floor)) {
				var fixture = body.GetFixtureList();
				while (fixture != null) {
					if (!fixture.IsSensor() && (fixture.GetFilterData().categoryBits & 1) != 0) {
						var polygon = Std.downcast(fixture.GetShape(), B2PolygonShape);
						if (polygon != null) drawWall(body, polygon);
					}
					fixture = fixture.GetNext();
				}
			}
			body = body.GetNext();
		}
	}

    function isTrapBody(body:B2Body, floor:DistributedDungeonFloor):Bool {
        var id:Dynamic = body.GetUserData();
        if (id == null || floor.remoteActors == null) return false;
        var npc = Std.downcast(floor.remoteActors.itemFor(id), NPCGameObject);
        if (npc == null) return false;
        if (npc.team == dBGlobals.DBGlobal.TEAM_3) return true;
        var gm = npc.gmNpc;
        if (gm == null) return false;
        var kind = Std.string(gm.Constant).toUpperCase();
        return kind.indexOf("TRAP") >= 0 || kind.indexOf("SPIKE") >= 0
            || kind.indexOf("FLAME_JET") >= 0;
    }

    /** Flood only exterior space, using collision geometry as the boundary. */
    function clipExitToWalls():Void {
        if (clippedExit != null) {
            map.removeChild(clippedExit);
            clippedExit.bitmapData.dispose();
            clippedExit = null;
        }
        if (exitPositions.length == 0) return;
        var density = 540 / Math.max(mapWidth, mapHeight);
        var pixelWidth = Std.int(Math.ceil(mapWidth * density));
        var pixelHeight = Std.int(Math.ceil(mapHeight * density));
        var transform = new Matrix(density, 0, 0, density);
        var boundary = new BitmapData(pixelWidth, pixelHeight, true, 0);
        boundary.draw(wallLayer, transform);
        var exterior = new BitmapData(pixelWidth, pixelHeight, false, 0xFFFFFF);
        for (y in 0...pixelHeight) for (x in 0...pixelWidth)
            if ((boundary.getPixel32(x, y) >>> 24) > 16) exterior.setPixel(x, y, 0);
        // Seed each edge, including disconnected exterior pockets at tile edges.
        for (x in 0...pixelWidth) {
            if (exterior.getPixel(x, 0) == 0xFFFFFF) exterior.floodFill(x, 0, 0x123456);
            if (exterior.getPixel(x, pixelHeight - 1) == 0xFFFFFF) exterior.floodFill(x, pixelHeight - 1, 0x123456);
        }
        for (y in 0...pixelHeight) {
            if (exterior.getPixel(0, y) == 0xFFFFFF) exterior.floodFill(0, y, 0x123456);
            if (exterior.getPixel(pixelWidth - 1, y) == 0xFFFFFF) exterior.floodFill(pixelWidth - 1, y, 0x123456);
        }
        var background = new BitmapData(pixelWidth, pixelHeight, true, 0);
        background.draw(exitLayer, transform);
        var correction = new BitmapData(pixelWidth, pixelHeight, true, 0);
        for (y in 0...pixelHeight) for (x in 0...pixelWidth) {
            if (exterior.getPixel(x, y) == 0x123456 && GateColors.isGateColor(background.getPixel(x, y))) {
                var color = ((x + y) % 18 < 2) ? palette.hatch : palette.outside;
                correction.setPixel32(x, y, 0xFF000000 | color);
            }
        }
        boundary.dispose();
        exterior.dispose();
        background.dispose();
        clippedExit = new Bitmap(correction);
        clippedExit.scaleX = clippedExit.scaleY = 1 / density;
        map.addChild(clippedExit);
    }

	function drawWall(body:B2Body, polygon:B2PolygonShape):Void {
		var count = polygon.GetVertexCount();
		if (count < 2) return;
		var vertices = polygon.GetVertices();
		var longest = 0.0;
		var shortest = Math.POSITIVE_INFINITY;
		for (i in 0...count) {
			var from:B2Vec2 = cast vertices[i];
			var to:B2Vec2 = cast vertices[(i + 1) % count];
			var dx = (to.x - from.x) * 50;
			var dy = (to.y - from.y) * 50;
			var length = Math.sqrt(dx * dx + dy * dy);
			if (length == 0) continue;
			longest = Math.max(longest, length);
			shortest = Math.min(shortest, length);
		}
		// Curved walls are assembled from short, narrow collision rectangles.
        // Keep these segments even when they are shorter than a straight wall.
        var narrowWall = count > 2 && longest >= 65 && shortest <= 110
            && longest >= shortest * 1.35;
        if (longest < MAIN_WALL_LENGTH && !narrowWall) return;
		if (count > 2) {
			// The game's generated filler bodies are exactly one tile square.
			if (Math.abs(longest - TILE_SIZE) < 1 && Math.abs(shortest - TILE_SIZE) < 1) return;
			// Keep long narrow walls and large blockers, and hide small compact scenery.
			if (!narrowWall && longest < LARGE_BLOCK_LENGTH && longest < shortest * 1.45) return;
		}

		var pen = wallLayer.graphics;
		pen.lineStyle(1.05, palette.edge, 0.96);
		if (count > 2) pen.beginFill(palette.wall, 1);
		wallVertex(body, cast vertices[0], true);
		for (i in 1...count) wallVertex(body, cast vertices[i], false);
		if (count > 2) {
			wallVertex(body, cast vertices[0], false);
			pen.endFill();
		}
	}

	function wallVertex(body:B2Body, vertex:B2Vec2, first:Bool):Void {
		var point = body.GetWorldPoint(vertex);
		var x = offX + (point.x * 50 - minX) * scale;
		var y = offY + (point.y * 50 - minY) * scale;
		if (first) wallLayer.graphics.moveTo(x, y);
		else wallLayer.graphics.lineTo(x, y);
	}

	function updateChests():Void {
		var floor = currentFloor();
		var pickups:Dynamic = floor == null ? null : Reflect.field(floor, "mDoobers");
		var visibleIds = new Map<UInt, Bool>();
		if (pickups != null) {
			for (pickup in Dictionaries.keys(pickups)) {
				var chest = Std.downcast(pickup, DooberGameObject);
				if (chest == null || chest.isDestroyed || !chest.hasPosition || chest.mDooberData == null
					|| Reflect.field(chest, "hasOwnership") == true) continue;
				var kind = chest.mDooberData.ChestId;
				var art = chestArt.get(kind);
				if (art == null) continue;
				var marker = chestMarkers.get(chest.id);
				if (marker == null) {
                    var icon = new Bitmap(art);
                    icon.smoothing = true;
                    icon.scaleX = icon.scaleY = CHEST_SIZE / Math.max(art.width, art.height);
                    icon.x = -icon.width / 2;
                    icon.y = -icon.height / 2;
                    marker = new Sprite();
                    marker.addChild(icon);
                    marker.filters = [new GlowFilter(chestGlow(kind), 0.95, 2.5, 2.5, 2.5)];
					chestMarkers.set(chest.id, marker);
					chestLayer.addChild(marker);
				}
				marker.scaleX = marker.scaleY = markerScale;
				marker.x = PAD + offX + (chest.positionX - minX) * scale;
				marker.y = HEADER_H + PAD + offY + (chest.positionY - minY) * scale;
				visibleIds.set(chest.id, true);
			}
		}
		var gone = [for (id in chestMarkers.keys()) if (!visibleIds.exists(id)) id];
		for (id in gone) {
			chestLayer.removeChild(chestMarkers.get(id));
			chestMarkers.remove(id);
		}
	}

	function updateTimer():Void {
		var s = Std.int((Lib.getTimer() - startTime) / 1000);
		var time = pad2(Std.int(s / 3600)) + ":" + pad2(Std.int(s % 3600 / 60)) + ":" + pad2(s % 60);
		if (timerLabel.text != time) timerLabel.text = time;
	}

	inline function pad2(n:Int):String
		return n < 10 ? "0" + n : "" + n;

	function drawDungeonIfReady():Void {
		var positions:Array<Vector3D> = getTilePositions();
		if (positions == null || positions.length == 0) return;

		palette = MapPalette.detect(ctx);
		drawnTileSignature = tileSignature();
		refreshExits();

		// World bounds of the tiles, then scale to fit the panel
		var maxX = positions[0].x, maxY = positions[0].y;
		minX = maxX; minY = maxY;
		for (p in positions) {
			minX = Math.min(minX, p.x); minY = Math.min(minY, p.y);
			maxX = Math.max(maxX, p.x); maxY = Math.max(maxY, p.y);
		}
		var worldW = maxX - minX + TILE_SIZE;
		var worldH = maxY - minY + TILE_SIZE;
		scale = Math.min((mapWidth - 12) / worldW, (mapHeight - 12) / worldH);
        // Use the same fitted floor scale for both axes of each marker.
        var defaultScale = Math.min((DEFAULT_MAP_W - 12) / worldW, (DEFAULT_MAP_H - 12) / worldH);
        markerScale = scale / defaultScale;
		offX = (mapWidth - worldW * scale) * 0.5;
		offY = (mapHeight - worldH * scale) * 0.5;

		if (clippedExit != null) {
			map.removeChild(clippedExit);
			clippedExit.bitmapData.dispose();
			clippedExit = null;
		}
		var pen = map.graphics;
		pen.clear();
		pen.beginFill(palette.outside);
		pen.drawRect(0, 0, mapWidth, mapHeight);
		pen.endFill();
		pen.lineStyle(0.65, palette.hatch, 0.28);
		drawMapHatching();
		pen.lineStyle(0, 0, 0);

		roomMask.graphics.clear();
		roomMask.graphics.beginFill(0xFFFFFF);
		var tileSize = TILE_SIZE * scale;
		for (p in positions) {
			var x = offX + (p.x - minX) * scale;
			var y = offY + (p.y - minY) * scale;
			roomMask.graphics.drawRect(x, y, tileSize, tileSize);
			pen.beginFill(palette.floor);
			pen.drawRect(x, y, tileSize, tileSize);
			pen.endFill();
		}
		roomMask.graphics.endFill();

		drawExitTiles();
		updateWalls();
        // Let the first map frame render before computing the exit clipping.
        clipAfter = exitPositions.length == 0 ? -1 : Lib.getTimer() + 120;
		drawnFloor = currentFloor();
		nextMarkerRefresh = 0;
		nextWallRefresh = Lib.getTimer() + WALL_REFRESH_MS;
		monsterLayer.graphics.clear(); // no stale dots from the previous floor
		breakableLayer.graphics.clear();
		ready = true;
	}

    function drawExitTiles():Void {
        var pen = exitLayer.graphics;
        pen.clear();
        var markers = exitMarkers.graphics;
        markers.clear();
        var size = TILE_SIZE * scale;
        for (position in exitPositions) {
            var color = exitColors.get(posKey(position.x, position.y));
            if (color == null) continue;
            pen.beginFill(color);
            var x = offX + (position.x - minX) * scale;
            var y = offY + (position.y - minY) * scale;
            pen.drawRect(x, y, size, size);
            pen.endFill();
            // An outlined marker remains readable even if wall clipping hides the fill.
            var radius = Math.max(2, Math.min(3.5, size * 0.17));
            var mx = x + size / 2;
            var my = y + Math.max(radius, size * 0.23);
            markers.lineStyle(0.85, 0x171C23);
            markers.beginFill(color);
            markers.moveTo(mx, my - radius);
            markers.lineTo(mx + radius, my);
            markers.lineTo(mx, my + radius);
            markers.lineTo(mx - radius, my);
            markers.lineTo(mx, my - radius);
            markers.endFill();
        }
    }

	/** Draw the whole field first. Opaque room fills cover the lines inside each playable room. */
	function drawMapHatching():Void {
		var pen = map.graphics;
		var spacing = 6.;
		var first = Math.ceil(-mapHeight / spacing);
		var last = Math.floor(mapWidth / spacing);
		for (i in first...(last + 1)) {
			var offset = i * spacing;
			var x = Math.max(0, offset);
			var y = Math.max(0, -offset);
			var length = Math.min(mapWidth - x, mapHeight - y);
			if (length <= 0) continue;
			pen.moveTo(x, y);
			pen.lineTo(x + length, y + length);
		}
	}

	/** Moves the player marker and the ally markers in a single pass over the heroes. */
	function updateHeroMarkers():Void {
		for (hero in ctx.state.heroes) {
			var mx = PAD + offX + (hero.x - minX) * scale;
			var my = HEADER_H + PAD + offY + (hero.y - minY) * scale;
			var marker = markersByHero.get(hero.id);
			if (marker == null) {
				marker = new Sprite();
				var radius = hero.local ? LOCAL_HERO_RADIUS : 6.0;
				var color = hero.player == null ? 0xFFFFFF : PlayerColor.fromName(hero.player.name);
				marker.graphics.beginFill(0x18232D);
				marker.graphics.drawCircle(0, 0, radius);
				marker.graphics.endFill();
				if (hero.player != null) {
					var portrait = hero.player.createPortrait(Std.int(radius * 2));
					portrait.x = -radius;
					portrait.y = -radius;
					var crop = new Sprite();
					crop.graphics.beginFill(0xFFFFFF);
					crop.graphics.drawCircle(0, 0, radius);
					crop.graphics.endFill();
					marker.addChild(portrait);
					marker.addChild(crop);
					portrait.mask = crop;
				}
				var ring = new Sprite();
				ring.graphics.lineStyle(1.8, color);
				ring.graphics.drawCircle(0, 0, radius);
				marker.addChild(ring);
				markersByHero.set(hero.id, marker);
				mapContent.addChildAt(marker, mapContent.getChildIndex(chestLayer));
			}
			marker.scaleX = marker.scaleY = markerScale;
			marker.x = mx;
			marker.y = my;
		}
	}

	public function removeHeroMarker(id:UInt):Void {
		var marker = markersByHero.get(id);
		if (marker == null) return;
		mapContent.removeChild(marker);
		markersByHero.remove(id);
	}

	public function destroy():Void {
		destroyed = true;
		if (assets != null) assets.destroy();
		assets = null;
		endPan(null);
		viewport.removeEventListener(openfl.events.MouseEvent.MOUSE_DOWN, startPan);
		chestLayer.removeChildren();
		for (art in chestArt) art.dispose();
		if (clippedExit != null) {
			clippedExit.bitmapData.dispose();
			clippedExit = null;
		}
		for (art in counterArt) art.dispose();
		counterArt = [];
		chestArt = new Map();
		chestMarkers = new Map();
		for(button in buttons)button.removeChildren();buttons=[];
		controls.destroy();
		removeEventListener(Event.ENTER_FRAME, onFrame);
		graphics.clear();
		wallLayer.mask = null;
		roomMask.graphics.clear();
		map.graphics.clear();
		for (m in markersByHero) if (m.parent == mapContent) mapContent.removeChild(m);
		markersByHero.clear();
		monsterLayer.graphics.clear();
	}
}
