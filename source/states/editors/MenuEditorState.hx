package states.editors;

import haxe.Json;
#if HSCRIPT_ALLOWED
import psychlua.HScript;
#end

/**
 * EDITOR DE MENUS (capas + HScript)
 *
 * - Solo funciona si el juego tiene soporte de mods (MODS_ALLOWED). Si no, muestra un aviso.
 * - Funciona con un mod seleccionado (mods/TuMod/...) o SIN mod, directamente en mods/...
 * - Imagenes:  <mods o mods/TuMod>/images/menus/*.png   (se detectan solas)
 * - Layout:    <mods o mods/TuMod>/data/menus/<nombre>.json
 * - Script:    <mods o mods/TuMod>/scripts/menus/<nombre>.hx   (opcional, HScript)
 *
 * Uso en cualquier state:
 *     var menu = new MenuLayout('custom_menu');
 *     add(menu);
 */
typedef MenuItemData =
{
	var image:String;
	var x:Float;
	var y:Float;
	var scale:Float;
	var layer:Int; // 0 = al fondo, mayor = mas adelante
}

class MenuLayer extends FlxSprite
{
	public var imageName:String = '';
}

#if MODS_ALLOWED
class MenuLayout extends FlxTypedGroup<MenuLayer>
{
	public var name:String;

	#if HSCRIPT_ALLOWED
	var script:HScript = null;
	#end

	public function new(name:String, runScript:Bool = true)
	{
		super();
		this.name = name;

		var path:String = findFile('data/menus/$name.json');
		if (path != null)
		{
			try
			{
				var data:Array<MenuItemData> = Json.parse(File.getContent(path));
				data.sort(function(a:MenuItemData, b:MenuItemData) return a.layer - b.layer);
				for (d in data)
					addLayer(d.image, d.x, d.y, d.scale);
			}
			catch (e:Dynamic)
			{
				trace('Error cargando el layout "$name": $e');
			}
		}

		#if HSCRIPT_ALLOWED
		if (runScript) startScript();
		#end
	}

	public function addLayer(image:String, x:Float = 0, y:Float = 0, scale:Float = 1):MenuLayer
	{
		var spr:MenuLayer = new MenuLayer();
		spr.loadGraphic(Paths.image('menus/' + image));
		spr.imageName = image;
		spr.antialiasing = ClientPrefs.data.antialiasing;
		spr.scale.set(scale, scale);
		spr.updateHitbox();
		spr.setPosition(x, y);
		add(spr);
		return spr;
	}

	public function getLayer(image:String):MenuLayer
	{
		for (l in members)
			if (l != null && l.imageName == image) return l;
		return null;
	}

	/** dir = 1 sube la capa (mas adelante), dir = -1 la baja (mas atras). */
	public function moveLayer(spr:MenuLayer, dir:Int):Void
	{
		var i:Int = members.indexOf(spr);
		var n:Int = i + dir;
		if (i < 0 || n < 0 || n >= members.length) return;
		remove(spr, true);
		insert(n, spr);
	}

	public function save():Void
	{
		var out:Array<MenuItemData> = [];
		for (s in members)
		{
			if (s == null) continue;
			out.push({image: s.imageName, x: s.x, y: s.y, scale: s.scale.x, layer: out.length});
		}

		var dir:String = root() + '/data/menus';
		ensureDir(dir);
		File.saveContent(dir + '/' + name + '.json', Json.stringify(out, '\t'));
	}

	#if HSCRIPT_ALLOWED
	function startScript():Void
	{
		var file:String = findFile('scripts/menus/$name.hx');
		if (file == null) return;

		try
		{
			// OJO: revisa que esta firma coincida con tu psychlua/HScript.hx
			script = new HScript(null, file, null, true);
			script.set('layout', this);
			script.set('addLayer', addLayer);
			script.set('getLayer', getLayer);
			script.set('moveLayer', moveLayer);
			script.execute();
			if (script.exists('onCreate')) script.executeFunction('onCreate');
		}
		catch (e:Dynamic)
		{
			trace('Error en el script del menu "$name": $e');
			script = null;
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (script != null && script.exists('onUpdate'))
			script.executeFunction('onUpdate', [elapsed]);
	}

	override function destroy()
	{
		if (script != null)
		{
			if (script.exists('onDestroy')) script.executeFunction('onDestroy');
			script.destroy();
			script = null;
		}
		super.destroy();
	}
	#end

	// ---------- rutas (con mod seleccionado o directo en mods/) ----------

	/** Carpeta del mod actual; si no hay mod seleccionado, la carpeta mods/ */
	public static function root():String
	{
		var dir:String = Mods.currentModDirectory;
		var r:String = (dir != null && dir.length > 0) ? Paths.mods(dir) : Paths.mods('');
		return trimSlash(r);
	}

	/** Carpeta mods/ (para contenido global, sin mod pack). */
	public static function globalRoot():String
		return trimSlash(Paths.mods(''));

	static function trimSlash(r:String):String
	{
		while (r.length > 1 && r.endsWith('/'))
			r = r.substr(0, r.length - 1);
		return r;
	}

	/** Busca primero en el mod actual y despues en mods/. Devuelve null si no existe. */
	public static function findFile(rel:String):String
	{
		var a:String = root() + '/' + rel;
		if (FileSystem.exists(a)) return a;
		var b:String = globalRoot() + '/' + rel;
		if (FileSystem.exists(b)) return b;
		return null;
	}

	public static function ensureDir(path:String):Void
	{
		var parts:Array<String> = path.split('/');
		var cur:String = '';
		for (i in 0...parts.length)
		{
			var p:String = parts[i];
			if (p == '')
			{
				if (i == 0) cur = '/';
				continue;
			}
			cur = (cur == '' || cur == '/') ? cur + p : cur + '/' + p;
			if (!FileSystem.exists(cur)) FileSystem.createDirectory(cur);
		}
	}

	/** Crea las carpetas necesarias aunque no exista ningun mod. */
	public static function prepareFolders():Void
	{
		ensureDir(root() + '/images/menus');
		ensureDir(root() + '/data/menus');
		ensureDir(root() + '/scripts/menus');
	}
}

typedef EditorButton =
{
	var box:FlxSprite;
	var label:FlxText;
	var onTap:Void->Void;
}

class MenuEditorState extends MusicBeatState
{
	var layoutName:String = 'custom_menu';
	var images:Array<String> = [];
	var curImage:Int = 0;

	var layout:MenuLayout;
	var selected:MenuLayer = null;
	var dragging:MenuLayer = null;

	var infoText:FlxText;
	var buttons:Array<EditorButton> = [];

	override function create()
	{
		FlxG.mouse.visible = true;

		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF222222);
		add(bg);

		MenuLayout.prepareFolders();
		scanImages();

		// false = no ejecutar scripts dentro del editor, solo editar capas
		layout = new MenuLayout(layoutName, false);
		add(layout);

		makeButton('Adelante', 0, function() { if (selected != null) layout.moveLayer(selected, 1); });
		makeButton('Atras', 1, function() { if (selected != null) layout.moveLayer(selected, -1); });
		makeButton('Escala +', 2, function() rescale(1.1));
		makeButton('Escala -', 3, function() rescale(1 / 1.1));
		makeButton('Borrar', 4, function()
		{
			if (selected == null) return;
			layout.remove(selected, true);
			selected.destroy();
			selected = null;
			dragging = null;
		});

		infoText = new FlxText(10, 10, FlxG.width - 220, '', 24);
		infoText.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		infoText.scrollFactor.set();
		add(infoText);
		updateInfo();

		addTouchPad('UP_DOWN', 'A_B');
		super.create();
	}

	function makeButton(text:String, index:Int, onTap:Void->Void)
	{
		var box:FlxSprite = new FlxSprite(FlxG.width - 190, 20 + index * 50).makeGraphic(170, 40, 0xCC000000);
		box.scrollFactor.set();
		add(box);

		var label:FlxText = new FlxText(box.x, box.y + 6, 170, text, 24);
		label.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, CENTER);
		label.scrollFactor.set();
		add(label);

		buttons.push({box: box, label: label, onTap: onTap});
	}

	function rescale(factor:Float)
	{
		if (selected == null) return;
		selected.scale.x *= factor;
		selected.scale.y *= factor;
		selected.updateHitbox();
	}

	function scanImages()
	{
		images = [];
		for (base in [MenuLayout.root(), MenuLayout.globalRoot()])
		{
			var folder:String = base + '/images/menus';
			if (!FileSystem.exists(folder) || !FileSystem.isDirectory(folder)) continue;

			for (file in FileSystem.readDirectory(folder))
			{
				if (!file.endsWith('.png')) continue;
				var n:String = file.substr(0, file.length - 4);
				if (!images.contains(n)) images.push(n);
			}
		}
		images.sort(function(a:String, b:String) return a < b ? -1 : 1);
	}

	function changeImage(change:Int)
	{
		if (images.length < 1) return;
		curImage = FlxMath.wrap(curImage + change, 0, images.length - 1);
		updateInfo();
	}

	function updateInfo()
	{
		var img:String = images.length > 0 ? images[curImage] : '(pon .png en images/menus)';
		var layerNum:String = selected != null ? Std.string(layout.members.indexOf(selected) + 1) : '-';
		infoText.text = 'Imagen: $img [${curImage + 1}/${images.length}]\n'
			+ 'Capa: $layerNum/${layout.members.length}\n'
			+ 'A: agregar | B: guardar y salir';
	}

	override function update(elapsed:Float)
	{
		if (controls.UI_UP_P) changeImage(-1);
		if (controls.UI_DOWN_P) changeImage(1);

		if (controls.ACCEPT && images.length > 0)
			selected = layout.addLayer(images[curImage], FlxG.width / 2 - 100, FlxG.height / 2 - 100);

		if (FlxG.mouse.justPressed)
		{
			dragging = null;
			var hitButton:Bool = false;
			for (b in buttons)
			{
				if (FlxG.mouse.overlaps(b.box))
				{
					b.onTap();
					hitButton = true;
					break;
				}
			}

			if (!hitButton)
			{
				// la capa de mas arriba tiene prioridad
				var i:Int = layout.members.length - 1;
				while (i >= 0)
				{
					var s:MenuLayer = layout.members[i];
					if (s != null && FlxG.mouse.overlaps(s))
					{
						dragging = s;
						selected = s;
						break;
					}
					i--;
				}
			}
		}
		if (FlxG.mouse.justReleased) dragging = null;
		if (dragging != null && FlxG.mouse.pressed)
		{
			dragging.x += FlxG.mouse.deltaX;
			dragging.y += FlxG.mouse.deltaY;
		}

		for (l in layout.members)
			if (l != null) l.alpha = (selected == null || l == selected) ? 1 : 0.6;

		updateInfo();

		if (controls.BACK)
		{
			layout.save();
			FlxG.mouse.visible = false;
			MusicBeatState.switchState(new MasterEditorMenu());
		}

		super.update(elapsed);
	}
}
#else
// ---------- Sin soporte de mods: el editor no funciona ----------
class MenuLayout extends FlxTypedGroup<MenuLayer>
{
	public function new(name:String, runScript:Bool = true)
		super();

	public function addLayer(image:String, x:Float = 0, y:Float = 0, scale:Float = 1):MenuLayer
		return null;

	public function getLayer(image:String):MenuLayer
		return null;
}

class MenuEditorState extends MusicBeatState
{
	override function create()
	{
		var txt:FlxText = new FlxText(0, 0, FlxG.width, 'Este editor necesita soporte de mods (MODS_ALLOWED).\nPulsa B para volver.', 32);
		txt.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, CENTER);
		txt.screenCenter();
		add(txt);

		addTouchPad('NONE', 'B');
		super.create();
	}

	override function update(elapsed:Float)
	{
		if (controls.BACK) MusicBeatState.switchState(new MasterEditorMenu());
		super.update(elapsed);
	}
}
#end
