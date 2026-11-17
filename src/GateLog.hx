package mods.dungeon_minimap;
/** Opt-in local diagnostics. No open file handles or network access. */
class GateLog {
 public var enabled=false;
 var directory:String;
 var previous:Map<String,String>=new Map();
 var sequence=0;
 public function new(data:String){
  directory=data+"/gate-logs";
  enabled=sys.FileSystem.exists(data+"/gate_logging.enabled");
  if(enabled)try{if(!sys.FileSystem.exists(directory))sys.FileSystem.createDirectory(directory);}catch(_:Dynamic){enabled=false;}
 }
 public function record(floor:String,tileId:String,x:Float,y:Float,mode:String,color:Int,tile:Dynamic):Void {
  if(!enabled)return;
  try{
   var actors:Dynamic=tile==null?null:Reflect.getProperty(tile,"NPCGameObjects");var entries:Array<Dynamic>=[];
   if(actors!=null){if(Std.isOfType(actors,Array))entries=cast actors;else{var fn=Reflect.field(actors,"iterator");if(fn!=null){var it:Dynamic=Reflect.callMethod(actors,fn,[]);while(it.hasNext())entries.push(it.next());}}}
   var details:Array<String>=[];
   for(actor in entries){var gm=Reflect.getProperty(actor,"gmNpc");details.push(haxe.Json.stringify({type:Reflect.getProperty(actor,"type"),name:gm==null?null:Reflect.field(gm,"Constant"),species:gm==null?null:Reflect.field(gm,"Species"),trigger:Reflect.getProperty(actor,"triggerState"),breakable:Reflect.getProperty(actor,"isAttackable")}));}
   details.sort(function(a:String,b:String):Int{return Reflect.compare(a,b);});
   var snapshot=haxe.Json.stringify({floor:floor,tile:tileId,x:x,y:y,mode:mode,color:StringTools.hex(color,6),actors:details});
   var key=floor+":"+x+":"+y;
   if(previous.get(key)==snapshot)return;
   previous.set(key,snapshot);
   var path=directory+"/gates-"+sequence+".jsonl";
   if(sys.FileSystem.exists(path)&&sys.FileSystem.stat(path).size>2097152){sequence=(sequence+1)%5;path=directory+"/gates-"+sequence+".jsonl";sys.io.File.saveContent(path,"");}
   var output=sys.io.File.append(path,false);
   try{output.writeString(haxe.Json.stringify({time:Date.now().toString(),snapshot:haxe.Json.parse(snapshot)})+"\n");}catch(error:Dynamic){output.close();throw error;}
   output.close();
  }catch(_:Dynamic){enabled=false;}
 }
 public function clear():Void {previous=new Map();}
}
