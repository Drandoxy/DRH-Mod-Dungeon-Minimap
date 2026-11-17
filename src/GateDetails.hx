package mods.dungeon_minimap;
/** Full raw identifiers for screenshot reports; deliberately independent of color classification. */
class GateDetails {
 public static function describe(tileId:String,mode:String,color:Null<Int>,tile:Dynamic):String{
  var lines=["Gate mode: "+(mode==null?"UNKNOWN":mode)];
  var seen:Array<String>=[];
  var actors:Dynamic=tile==null?null:Reflect.getProperty(tile,"NPCGameObjects");var entries:Array<Dynamic>=[];
  if(actors!=null){if(Std.isOfType(actors,Array))entries=cast actors;else{var fn=Reflect.field(actors,"iterator");if(fn!=null){var it:Dynamic=Reflect.callMethod(actors,fn,[]);while(it.hasNext())entries.push(it.next());}}}
  for(actor in entries){
   var type=Std.parseInt(Std.string(Reflect.getProperty(actor,"type")));var gm=Reflect.getProperty(actor,"gmNpc");
   var constant=gm==null?null:Reflect.field(gm,"Constant");
   var name=constant==null?"UNKNOWN":Std.string(constant);
   var suffix=type==null?-1:type%10000;
   if(name.indexOf("EXIT_GATE")<0&&(type==null||type<2000000||type>=3000000||(suffix!=101&&suffix!=201)))continue;
   var detail=(type==null?"UNKNOWN":Std.string(type))+" | "+name;
   if(seen.indexOf(detail)>=0)continue;
   seen.push(detail);lines.push(detail);
  }
  if(lines.length==1)lines.push("Exit gate: not available yet");
  return lines.join("\n");
 }
}
