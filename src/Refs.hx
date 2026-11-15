package mods.dungeon_minimap;

import distributedObjects.NPCGameObject;
import distributedObjects.HeroGameObjectOwner;

class Refs {
	public var localHero:Null<HeroGameObjectOwner>;
	public var breakableWalls:Map<UInt, NPCGameObject> = new Map();

	public function new() {}
}
