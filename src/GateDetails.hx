package mods.dungeon_minimap;
/** Full raw identifiers for screenshot reports; deliberately independent of color classification. */
class GateDetails {
 public static function describe(tileId:String,mode:String,color:Null<Int>,tile:Dynamic):String{
  var lines=["Tile: "+tileId+" | Mode: "+(mode==null?"UNKNOWN":mode)+" | Color: "+(color==null?"UNKNOWN":"#"+StringTools.hex(color,6))];
  var actors:Dynamic=tile==null?null:Reflect.getProperty(tile,"NPCGameObjects");var entries:Array<Dynamic>=[];
  if(actors!=null){if(Std.isOfType(actors,Array))entries=cast actors;else{var fn=Reflect.field(actors,"iterator");if(fn!=null){var it:Dynamic=Reflect.callMethod(actors,fn,[]);while(it.hasNext())entries.push(it.next());}}}
  for(actor in entries){
   var type=Std.parseInt(Std.string(Reflect.getProperty(actor,"type")));var gm=Reflect.getProperty(actor,"gmNpc");
   var species=gm==null?null:Reflect.field(gm,"Species");
   if(species!="DOOR"&&(type==null||type<2000000||type>=3000000))continue;
   var constant=gm==null?null:Reflect.field(gm,"Constant");var state=Reflect.getProperty(actor,"triggerState");var attack=Reflect.getProperty(actor,"isAttackable");
   lines.push("Gate: "+(type==null?"UNKNOWN":Std.string(type))+" | "+(constant==null?"UNKNOWN":Std.string(constant))+" | Trigger: "+Std.string(state)+" | Breakable: "+Std.string(attack));
  }
  if(lines.length==1)lines.push("Gate actor: not available yet");
  return lines.join("\n");
 }
}
