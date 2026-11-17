package states.editors;

#if MODS_ALLOWED
import backend.ui.*;

/**
 * EDITOR DE CREDITOS
 *
 * - Lee y guarda  <mod>/data/credits.txt  (o mods/data/credits.txt si no hay mod seleccionado)
 * - Formato de cada linea:  Nombre::icono::Descripcion::Enlace::ColorHex
 * - Una linea con solo texto es un titulo de seccion; una linea vacia es un separador.
 * - Toca una fila (o usa ARRIBA/ABAJO) para elegirla y edita sus campos a la derecha.
 * - B: guarda (si hubo cambios) y sale.
 * - Solo funciona con soporte de mods (MODS_ALLOWED).
 */
class CreditsEditorState extends MusicBeatState implements PsychUIEventHandler.PsychUIEvent
{
	static inline var VISIBLE_ROWS:Int = 12;
	static final FIELD_NAMES:Array<String> = ['Nombre', 'Icono (credits/...)', 'Descripcion', 'Enlace', 'Color (hex)'];

	var entries:Array<Array<String>> = [];
	var curSelected:Int = 0;
	var rowStart:Int = 0;
	var dirty:Bool = false;
	var updatingFields:Bool = false;

	var rows:FlxTypedGroup<FlxText>;
	var inputs:Array<PsychUIInputText> = [];
	var infoText:FlxText;

	override function create()
	{
		FlxG.mouse.visible = true;

		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF222222);
		add(bg);

		ensureDir(folder());
		load();
		if (entries.length < 1) entries.push(['Nuevo credito', '', '', '', 'FFFFFF']);

		infoText = new FlxText(10, 10, 540, 'Toca una fila para editarla\nB: guardar y salir', 20);
		infoText.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, LEFT);
		infoText.scrollFactor.set();
		add(infoText);

		rows = new FlxTypedGroup<FlxText>();
		add(rows);
		for (i in 0...VISIBLE_ROWS)
		{
			var t:FlxText = new FlxText(10, 80 + i * 34, 530, '', 24);
			t.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.WHITE, LEFT);
			rows.add(t);
		}

		for (i in 0...FIELD_NAMES.length)
		{
			var label:FlxText = new FlxText(560, 20 + i * 80, 640, FIELD_NAMES[i], 20);
			label.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.WHITE, LEFT);
			add(label);

			var input:PsychUIInputText = new PsychUIInputText(560, 48 + i * 80, 640, '', 20);
			add(input);
			inputs.push(input);
		}

		// botones (fila 1 y fila 2)
		makeButton('Nuevo', 560, 440, addEntry);
		makeButton('Seccion', 720, 440, addSection);
		makeButton('Separador', 880, 440, addSeparator);
		makeButton('Borrar', 1040, 440, deleteEntry);
		makeButton('Subir', 560, 490, function() moveEntry(-1));
		makeButton('Bajar', 720, 490, function() moveEntry(1));
		makeButton('Guardar', 880, 490, save);

		setSelected(0);

		addTouchPad('UP_DOWN', 'B');
		super.create();
	}

	function makeButton(label:String, x:Float, y:Float, onClick:Void->Void)
	{
		var b:PsychUIButton = new PsychUIButton(x, y, label, onClick);
		add(b);
	}

	// ---------- carga / guardado ----------

	function load()
	{
		entries = [];
		var path:String = folder() + '/credits.txt';
		if (!FileSystem.exists(path)) return;

		for (line in File.getContent(path).split('\n'))
			entries.push(line.replace('\r', '').split('::'));

		// quitar separadores vacios del final
		while (entries.length > 0 && entries[entries.length - 1].length <= 1 && entries[entries.length - 1][0] == '')
			entries.pop();
	}

	function save()
	{
		var lines:Array<String> = [];
		for (e in entries)
		{
			if (e.length <= 1)
			{
				lines.push(e.length > 0 ? e[0] : '');
				continue;
			}
			var parts:Array<String> = [];
			for (i in 0...5)
				parts.push(i < e.length ? e[i] : '');
			lines.push(parts.join('::'));
		}
		while (lines.length > 0 && lines[lines.length - 1] == '')
			lines.pop();

		ensureDir(folder());
		File.saveContent(folder() + '/credits.txt', lines.join('\n'));
		dirty = false;
		infoText.text = 'Guardado en ${folder()}/credits.txt\nB: salir';
	}

	// ---------- seleccion y lista ----------

	function setSelected(i:Int)
	{
		curSelected = Std.int(FlxMath.bound(i, 0, entries.length - 1));
		fillInputs();
		refreshRows();
	}

	function fillInputs()
	{
		updatingFields = true;
		var e:Array<String> = entries[curSelected];
		for (i in 0...inputs.length)
			inputs[i].text = (i < e.length) ? e[i] : '';
		updatingFields = false;
	}

	function display(e:Array<String>):String
	{
		if (e.length <= 1) return (e[0] == '') ? '--------' : '== ' + e[0] + ' ==';
		return e[0];
	}

	function refreshRows()
	{
		rowStart = Std.int(FlxMath.bound(curSelected - Std.int(VISIBLE_ROWS / 2), 0, Math.max(0, entries.length - VISIBLE_ROWS)));
		for (k in 0...rows.length)
		{
			var idx:Int = rowStart + k;
			var t:FlxText = rows.members[k];
			if (idx < entries.length)
			{
				t.text = display(entries[idx]);
				t.color = (idx == curSelected) ? FlxColor.YELLOW : FlxColor.WHITE;
			}
			else t.text = '';
		}
	}

	public function UIEvent(id:String, sender:Dynamic)
	{
		if (id == PsychUIInputText.CHANGE_EVENT && (sender is PsychUIInputText))
		{
			var idx:Int = inputs.indexOf(sender);
			if (idx > -1) onFieldChanged(idx, inputs[idx].text);
		}
	}

	function onFieldChanged(idx:Int, value:String)
	{
		if (updatingFields) return;

		var e:Array<String> = entries[curSelected];

		// si el valor no cambio (por ejemplo, al rellenar los campos), no hacer nada
		var current:String = (idx < e.length) ? e[idx] : '';
		if (value.replace('::', ':') == current) return;

		if (idx > 0)
		{
			// pasa de titulo/separador a credito completo
			while (e.length < 5)
				e.push(e.length == 4 ? 'FFFFFF' : '');
		}
		e[idx] = value.replace('::', ':');
		dirty = true;
		refreshRows();
	}

	// ---------- acciones ----------

	function addEntry()
		insertAfter(['Nuevo credito', '', '', '', 'FFFFFF']);

	function addSection()
		insertAfter(['Seccion']);

	function addSeparator()
		insertAfter(['']);

	function insertAfter(e:Array<String>)
	{
		entries.insert(curSelected + 1, e);
		dirty = true;
		setSelected(curSelected + 1);
	}

	function deleteEntry()
	{
		if (entries.length <= 1) return;
		entries.splice(curSelected, 1);
		dirty = true;
		setSelected(curSelected);
	}

	function moveEntry(dir:Int)
	{
		var n:Int = curSelected + dir;
		if (n < 0 || n >= entries.length) return;
		var tmp:Array<String> = entries[curSelected];
		entries[curSelected] = entries[n];
		entries[n] = tmp;
		dirty = true;
		setSelected(n);
	}

	// ---------- update ----------

	override function update(elapsed:Float)
	{
		// mientras escribes en un campo, no uses los controles (Backspace = BACK)
		if (PsychUIInputText.focusOn == null)
		{
			if (controls.UI_UP_P) setSelected(FlxMath.wrap(curSelected - 1, 0, entries.length - 1));
			if (controls.UI_DOWN_P) setSelected(FlxMath.wrap(curSelected + 1, 0, entries.length - 1));

			if (controls.BACK)
			{
				if (dirty) save();
				FlxG.mouse.visible = false;
				MusicBeatState.switchState(new MasterEditorMenu());
			}
		}

		if (FlxG.mouse.justPressed)
		{
			for (k in 0...rows.length)
			{
				var r:FlxText = rows.members[k];
				if (r.text != '' && FlxG.mouse.overlaps(r))
				{
					setSelected(rowStart + k);
					break;
				}
			}
		}

		super.update(elapsed);
	}

	// ---------- rutas (con mod o directo en mods/) ----------

	static function root():String
	{
		var dir:String = Mods.currentModDirectory;
		var r:String = (dir != null && dir.length > 0) ? Paths.mods(dir) : Paths.mods('');
		while (r.length > 1 && r.endsWith('/'))
			r = r.substr(0, r.length - 1);
		return r;
	}

	static function folder():String
		return root() + '/data';

	static function ensureDir(path:String):Void
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
}
#else
// ---------- Sin soporte de mods: el editor no funciona ----------
class CreditsEditorState extends MusicBeatState
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
