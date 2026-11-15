package substates;

import backend.Highscore;
import backend.Song;

import flixel.FlxCamera;
import flixel.math.FlxPoint;
import flixel.group.FlxSpriteGroup;
import flixel.util.FlxSpriteUtil;
import flixel.util.FlxStringUtil;

import mobile.backend.MobileScaleMode;


import states.StoryMenuState;
import states.FreeplayState;
import options.OptionsState;

#if MODS_ALLOWED
import sys.FileSystem;
import sys.io.File;
#end

typedef PauseDeco =
{
	var spr:FlxSprite;
	var vx:Float;
	var vy:Float;
	var rot:Float;
	var ph:Float;
	var base:Float;
	var t:Float;
}

class PauseSubState extends MusicBeatSubstate
{
	var grpMenuShit:FlxTypedGroup<FlxText>;
	var itemW:Array<Float> = [];
	var lerpSelected:Float = 0;

	var menuItems:Array<String> = [];
	var menuItemsOG:Array<String> = ['Resume', 'Restart Song', 'Chart Editor', 'Change Difficulty', 'Options', 'Exit to menu'];
	var difficultyChoices = [];
	var curSelected:Int = 0;

	var pauseMusic:FlxSound;
	var practiceText:FlxText;
	var skipTimeText:FlxText;
	var skipTimeTracker:FlxText;
	var curTime:Float = Math.max(0, Conductor.songPosition);

	var missingTextBG:FlxSprite;
	var missingText:FlxText;

	// --- Diseño futurista ---
	var pauseCam:FlxCamera;
	var W:Float = 1280; // ancho real de la pantalla (incluye pantalla ancha)
	var H:Float = 720;
	var edgeTop:Float = 430;    // x del borde diagonal arriba
	var edgeBottom:Float = 260; // x del borde diagonal abajo
	var leftW:Int = 460;
	var fontPath:String;

	var accent:FlxColor = 0xFF00E5FF;
	var introT:Float = 0;      // 0 -> 1 animacion de entrada
	var slide:Float = 0;       // desplazamiento del panel izquierdo durante la entrada
	var decoTime:Float = 0;

	var leftGroup:FlxSpriteGroup;
	var infoGroup:FlxSpriteGroup;
	var infoW:Float = 500;
	var selMarker:FlxSprite;
	var scanLine:FlxSprite;
	var bgSquares:Array<PauseDeco> = [];
	var edgeSquares:Array<PauseDeco> = [];

	// Datos opcionales de la canción y sus créditos
	
	public static var songName:String = null;

	inline function edgeAt(y:Float):Float
		return edgeTop + (edgeBottom - edgeTop) * (y / FlxG.height);

	inline function accentA(a:Int):FlxColor
		return FlxColor.fromRGB(accent.red, accent.green, accent.blue, a);

	// Achica un texto si es más ancho que maxW
	function fitText(t:FlxText, maxW:Float):Void
	{
		if (t.width > maxW)
		{
			var s:Float = maxW / t.width;
			t.scale.set(s, s);
			t.updateHitbox();
		}
	}

	// ---------- Datos de canción y créditos ----------
	function getChartField(names:Array<String>):String
	{
		try
		{
			for (n in names)
			{
				var v:Dynamic = Reflect.field(PlayState.SONG, n);
				if (v != null && Std.string(v).trim() != '') return Std.string(v).trim();
			}
		}
		catch (e:Dynamic) {}
		return null;
	}

	// Lee el primer creador disponible. Soporta créditos del mod activo,
	// créditos globales y archivos colocados directamente en la carpeta del mod.
	function getCreatorName():String
	{
		#if MODS_ALLOWED
		try
		{
			var files:Array<String> = [];
			var folder:String = Mods.currentModDirectory;

			if (folder != null && folder.length > 0)
			{
				files.push(Paths.mods(folder + '/data/credits.txt'));
				files.push(Paths.mods(folder + '/data/Credits.txt'));
				files.push(Paths.mods(folder + '/credits.txt'));
				files.push(Paths.mods(folder + '/Credits.txt'));
			}
			files.push(Paths.mods('data/credits.txt'));
			files.push(Paths.mods('data/Credits.txt'));
			files.push(Paths.mods('credits.txt'));
			files.push(Paths.mods('Credits.txt'));

			for (f in files)
			{
				if (f == null || !FileSystem.exists(f)) continue;

				var lines:Array<String> = File.getContent(f).split('\n');
				for (line in lines)
				{
					var clean:String = StringTools.trim(line);
					if (clean.length == 0 || clean.startsWith('#') || clean.startsWith('//')) continue;

					var parts:Array<String> = clean.split('::');
					if (parts.length >= 2)
					{
						var name:String = StringTools.trim(parts[0]);
						if (name.length > 0) return name;
					}
				}
			}
		}
		catch (e:Dynamic) {}
		#end
		return null;
	}

	override function create()
	{
		if(Difficulty.list.length < 2) menuItemsOG.remove('Change Difficulty'); //No need to change difficulty if there is only one!
		if(PlayState.chartingMode)
		{
			menuItemsOG.insert(2, 'Leave Charting Mode');
			var num:Int = 0;
			if(!PlayState.instance.startingSong)
			{
				num = 1;
				menuItemsOG.insert(3, 'Skip Time');
			}
			menuItemsOG.insert(3 + num, 'End Song');
			menuItemsOG.insert(4 + num, 'Toggle Practice Mode');
			menuItemsOG.insert(5 + num, 'Toggle Botplay');
		} else if(PlayState.instance.practiceMode && !PlayState.instance.startingSong)
			menuItemsOG.insert(3, 'Skip Time');
		menuItems = menuItemsOG;

		for (i in 0...Difficulty.list.length) {
			var diff:String = Difficulty.getString(i);
			difficultyChoices.push(diff);
		}
		difficultyChoices.push('BACK');

		pauseMusic = new FlxSound();
		try
		{
			var pauseSong:String = getPauseSong();
			if(pauseSong != null) pauseMusic.loadEmbedded(Paths.music(pauseSong), true, true);
		}
		catch(e:Dynamic) {}
		pauseMusic.volume = 0;
		pauseMusic.play(false, FlxG.random.int(0, Std.int(pauseMusic.length / 2)));

		FlxG.sound.list.add(pauseMusic);

		W = FlxG.width + MobileScaleMode.gameCutoutSize.x * 2;
		H = FlxG.height;
		edgeTop = H * 0.60;
		edgeBottom = H * 0.36;
		leftW = Std.int(edgeTop) + 30;

		fontPath = Paths.font('vcr.ttf');

		// Cámara propia, tan ancha como la pantalla
		pauseCam = new FlxCamera(0, 0, Std.int(W), Std.int(H));
		pauseCam.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(pauseCam, false);

		// Acento futurista fijo: el pause menu no depende de datos de Freeplay.
		accent = 0xFF00E5FF;

		// ---------- Fondo independiente de Freeplay ----------
		var dimAlpha:Float = 0.88;
		var dim:FlxSprite = new FlxSprite().makeGraphic(Std.int(W), Std.int(H), 0xFF03060D);
		dim.alpha = 0;
		dim.scrollFactor.set();
		add(dim);
		FlxTween.tween(dim, {alpha: dimAlpha}, 0.4, {ease: FlxEase.quartInOut});

		// Rejilla tenue
		var grid:FlxSprite = new FlxSprite().makeGraphic(Std.int(W), Std.int(H), FlxColor.TRANSPARENT, true);
		var step:Int = 60;
		for (gx in 0...Std.int(W / step) + 1)
			FlxSpriteUtil.drawLine(grid, gx * step, 0, gx * step, H, {thickness: 1, color: accentA(16)});
		for (gy in 0...Std.int(H / step) + 1)
			FlxSpriteUtil.drawLine(grid, 0, gy * step, W, gy * step, {thickness: 1, color: accentA(16)});
		grid.scrollFactor.set();
		add(grid);

		// Cuadritos de fondo (flotan, giran y laten)
		for (i in 0...26)
		{
			var s:Int = FlxG.random.int(6, 26);
			var spr:FlxSprite = new FlxSprite(FlxG.random.float(0, W), FlxG.random.float(0, H));
			if (i % 2 == 0) spr.makeGraphic(s, s, FlxColor.WHITE);
			else
			{
				spr.makeGraphic(s, s, FlxColor.TRANSPARENT, true);
				FlxSpriteUtil.drawRect(spr, 1, 1, s - 2, s - 2, FlxColor.TRANSPARENT, {thickness: 2, color: FlxColor.WHITE});
			}
			spr.color = accent;
			spr.alpha = 0;
			spr.angle = FlxG.random.float(0, 90);
			spr.scrollFactor.set();
			add(spr);
			bgSquares.push({spr: spr, vx: FlxG.random.float(-8, 8), vy: -FlxG.random.float(14, 46),
				rot: FlxG.random.float(-40, 40), ph: FlxG.random.float(0, 6.28), base: FlxG.random.float(0.07, 0.24), t: 0});
		}

		// Linea de escaneo
		scanLine = new FlxSprite().makeGraphic(Std.int(W), 3, FlxColor.WHITE);
		scanLine.color = accent;
		scanLine.alpha = 0.07;
		scanLine.scrollFactor.set();
		add(scanLine);

		// ---------- Panel izquierdo ----------
		leftGroup = new FlxSpriteGroup();
		add(leftGroup);

		var leftPanel:FlxSprite = new FlxSprite().makeGraphic(leftW, Std.int(H), FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawPolygon(leftPanel, [
			FlxPoint.get(0, 0), FlxPoint.get(edgeTop, 0),
			FlxPoint.get(edgeBottom, H), FlxPoint.get(0, H)
		], 0xE6050912);
		FlxSpriteUtil.drawLine(leftPanel, edgeTop, 0, edgeBottom, H, {thickness: 18, color: accentA(34)});
		FlxSpriteUtil.drawLine(leftPanel, edgeTop, 0, edgeBottom, H, {thickness: 9, color: accentA(80)});
		FlxSpriteUtil.drawLine(leftPanel, edgeTop, 0, edgeBottom, H, {thickness: 3, color: accent});
		var ty:Float = 18;
		while (ty < H) // marquitas tecnicas junto al borde
		{
			FlxSpriteUtil.drawLine(leftPanel, edgeAt(ty) - 16, ty, edgeAt(ty) - 6, ty, {thickness: 2, color: accentA(150)});
			ty += 36;
		}
		leftPanel.scrollFactor.set();
		leftGroup.add(leftPanel);

		var title:FlxText = new FlxText(36, 26, 0, Language.getPhrase('pause_title', 'PAUSED').toUpperCase(), 46);
		title.setFormat(fontPath, 46, accent, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		title.borderSize = 2;
		title.scrollFactor.set();
		leftGroup.add(title);

		var sub:FlxText = new FlxText(38, 80, 0, '// SYSTEM STANDBY', 16);
		sub.setFormat(fontPath, 16, FlxColor.WHITE, LEFT);
		sub.alpha = 0.5;
		sub.scrollFactor.set();
		leftGroup.add(sub);

		// Barra de seleccion fija al centro (la lista se desplaza)
		var barH:Int = 56;
		var barTop:Float = H / 2 - barH / 2;
		var wTop:Float = edgeAt(barTop) - 16;
		var wBot:Float = edgeAt(barTop + barH) - 16;
		var selBar:FlxSprite = new FlxSprite(0, barTop).makeGraphic(Std.int(wTop) + 4, barH + 2, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawPolygon(selBar, [
			FlxPoint.get(0, 0), FlxPoint.get(wTop, 0), FlxPoint.get(wBot, barH), FlxPoint.get(0, barH)
		], accentA(46));
		FlxSpriteUtil.drawLine(selBar, 0, 1, wTop, 1, {thickness: 2, color: accentA(170)});
		FlxSpriteUtil.drawLine(selBar, 0, barH, wBot, barH, {thickness: 2, color: accentA(170)});
		selBar.scrollFactor.set();
		leftGroup.add(selBar);

		selMarker = new FlxSprite(22, H / 2 - 8).makeGraphic(16, 16, FlxColor.WHITE);
		selMarker.color = accent;
		selMarker.scrollFactor.set();
		leftGroup.add(selMarker);

		// Cuadritos que recorren el borde del panel
		for (i in 0...18)
		{
			var s:Int = FlxG.random.int(4, 10);
			var spr:FlxSprite = new FlxSprite().makeGraphic(s, s, FlxColor.WHITE);
			spr.color = accent;
			spr.alpha = 0;
			spr.scrollFactor.set();
			add(spr);
			edgeSquares.push({spr: spr, vx: 0, vy: FlxG.random.float(0.05, 0.16) * (i % 2 == 0 ? 1 : -1),
				rot: FlxG.random.float(-120, 120), ph: FlxG.random.float(0, 6.28), base: FlxG.random.float(0.5, 1), t: FlxG.random.float(0, 1)});
		}

		// ---------- Menu ----------
		grpMenuShit = new FlxTypedGroup<FlxText>();
		add(grpMenuShit);

		// ---------- Panel de info (derecha) ----------
		buildInfoPanel();

		// Modo práctica / charting
		practiceText = new FlxText(20, infoH + 14, 0, Language.getPhrase("Practice Mode").toUpperCase(), 30);
		practiceText.scrollFactor.set();
		practiceText.setFormat(fontPath, 30, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		practiceText.x = W - (practiceText.width + 20);
		practiceText.visible = PlayState.instance.practiceMode;
		add(practiceText);

		var chartingText:FlxText = new FlxText(20, 0, 0, Language.getPhrase("Charting Mode").toUpperCase(), 30);
		chartingText.scrollFactor.set();
		chartingText.setFormat(fontPath, 30, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		chartingText.x = W - (chartingText.width + 20);
		chartingText.y = H - (chartingText.height + 20);
		chartingText.visible = PlayState.chartingMode;
		add(chartingText);

		missingTextBG = new FlxSprite().makeGraphic(Std.int(W), Std.int(H), FlxColor.BLACK);
		missingTextBG.alpha = 0.6;
		missingTextBG.scrollFactor.set();
		missingTextBG.visible = false;
		add(missingTextBG);

		missingText = new FlxText(50, 0, W - 100, '', 24);
		missingText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		missingText.scrollFactor.set();
		missingText.visible = false;
		add(missingText);

		FlxTween.num(0, 1, 0.5, {ease: FlxEase.quartOut}, function(v:Float) introT = v);

		regenMenu();
		updateItems(0);
		cameras = [pauseCam];

		addTouchPad(menuItems.contains('Skip Time') ? 'LEFT_FULL' : 'UP_DOWN', 'A');
		addTouchPadCamera();

		super.create();
	}

	var infoH:Float = 100;
	function buildInfoPanel():Void
	{
		// Dificultad SIEMPRE en inglés (nombre original de la lista, sin traducir)
		var diffIndex:Int = Std.int(Math.max(0, Math.min(Difficulty.list.length - 1, PlayState.storyDifficulty)));
		var diffName:String = Difficulty.list[diffIndex];
		diffName = diffName.charAt(0).toUpperCase() + diffName.substr(1);

		// Filas: [etiqueta, valor]. Las de musica/creador solo salen si hay datos.
		var rows:Array<Array<String>> = [];
		rows.push(['Difficulty', diffName]);
		var bb:String = Language.getPhrase("blueballed", "Blueballed: {1}", [PlayState.deathCounter]);
		var bi:Int = bb.indexOf(':');
		rows.push(bi > 0 ? [bb.substr(0, bi), bb.substr(bi + 1).trim()] : [bb, '']);
		var music:String = getChartField(['composer', 'artist', 'musician']);
		if (music != null) rows.push(['Music', music]);
		var creator:String = getCreatorName();
		if (creator != null) rows.push(['Creator', creator]);

		infoW = Math.min(520, W * 0.55);
		var textX:Float = W - infoW + 56;
		var textW:Float = W - textX - 24;
		infoH = 14 + 40 + rows.length * 26 + 10;

		infoGroup = new FlxSpriteGroup();
		add(infoGroup);

		var panel:FlxSprite = new FlxSprite(W - infoW, 0).makeGraphic(Std.int(infoW) + 10, Std.int(infoH) + 10, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawPolygon(panel, [
			FlxPoint.get(0, 0), FlxPoint.get(infoW, 0), FlxPoint.get(infoW, infoH), FlxPoint.get(40, infoH)
		], 0xE6050912);
		for (th in [[18, 34], [9, 80], [3, 255]])
		{
			var col:FlxColor = (th[1] == 255) ? accent : accentA(th[1]);
			FlxSpriteUtil.drawLine(panel, 0, 0, 40, infoH, {thickness: th[0], color: col});
			FlxSpriteUtil.drawLine(panel, 40, infoH, infoW, infoH, {thickness: th[0], color: col});
		}
		panel.scrollFactor.set();
		infoGroup.add(panel);

		var levelInfo:FlxText = new FlxText(textX, 10, 0, PlayState.SONG.song.toUpperCase(), 28);
		levelInfo.setFormat(fontPath, 28, FlxColor.WHITE, LEFT);
		levelInfo.scrollFactor.set();
		fitText(levelInfo, textW);
		infoGroup.add(levelInfo);

		for (i in 0...rows.length)
		{
			var label:String = rows[i][0].toUpperCase();
			var line:String = rows[i][1] == '' ? label : label + ' // ' + rows[i][1].toUpperCase();
			var t:FlxText = new FlxText(textX, 52 + i * 26, 0, line, 18);
			t.setFormat(fontPath, 18, FlxColor.WHITE, LEFT);
			t.addFormat(new FlxTextFormat(accent), 0, label.length);
			t.scrollFactor.set();
			fitText(t, textW);
			infoGroup.add(t);
		}
	}

	// ---------- Animacion de cuadritos / escaneo ----------
	function updateDecor(elapsed:Float):Void
	{
		decoTime += elapsed;
		slide = -(1 - introT) * leftW;
		leftGroup.x = slide;
		infoGroup.x = (1 - introT) * (infoW + 40);
		selMarker.angle += 120 * elapsed;

		scanLine.y = (scanLine.y + 150 * elapsed) % (H + 20);

		for (d in bgSquares)
		{
			d.spr.x += d.vx * elapsed;
			d.spr.y += d.vy * elapsed;
			d.spr.angle += d.rot * elapsed;
			if (d.spr.y < -40) { d.spr.y = H + 20; d.spr.x = FlxG.random.float(0, W); }
			if (d.spr.x > W + 40) d.spr.x = -30;
			else if (d.spr.x < -40) d.spr.x = W + 30;
			d.spr.alpha = d.base * (0.65 + 0.35 * Math.sin(decoTime * 1.8 + d.ph)) * introT;
		}

		for (d in edgeSquares)
		{
			d.t += d.vy * elapsed * 1.8;
			if (d.t > 1.05) d.t = -0.05;
			else if (d.t < -0.05) d.t = 1.05;

			var y:Float = d.t * H;
			var out:Float = -12 + 40 * (0.5 + 0.5 * Math.sin(decoTime * 2.2 + d.ph)); // se despega del borde y vuelve
			d.spr.setPosition(edgeAt(y) + out + slide - d.spr.width / 2, y - d.spr.height / 2);
			d.spr.angle += d.rot * elapsed;
			d.spr.alpha = d.base * (0.35 + 0.65 * Math.abs(Math.sin(decoTime * 3 + d.ph))) * introT;
		}
	}

	function getPauseSong()
	{
		var formattedSongName:String = (songName != null ? Paths.formatToSongPath(songName) : '');
		var formattedPauseMusic:String = Paths.formatToSongPath(ClientPrefs.data.pauseMusic);
		if(formattedSongName == 'none' || (formattedSongName != 'none' && formattedPauseMusic == 'none')) return null;

		return (formattedSongName != '') ? formattedSongName : formattedPauseMusic;
	}

	var holdTime:Float = 0;
	var cantUnpause:Float = 0.1;
	override function update(elapsed:Float)
	{
		cantUnpause -= elapsed;
		if (pauseMusic.volume < 0.5)
			pauseMusic.volume += 0.01 * elapsed;

		super.update(elapsed);
		updateDecor(elapsed);

		if(controls.BACK)
		{
			close();
			return;
		}

		if(FlxG.keys.justPressed.F5)
		{
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			PlayState.nextReloadAll = true;
			MusicBeatState.resetState();
		}

		updateItems(elapsed);
		updateSkipTextStuff();
		if (controls.UI_UP_P)
		{
			changeSelection(-1);
		}
		if (controls.UI_DOWN_P)
		{
			changeSelection(1);
		}

		var daSelected:String = menuItems[curSelected];
		switch (daSelected)
		{
			case 'Skip Time':
				if (controls.UI_LEFT_P)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
					curTime -= 1000;
					holdTime = 0;
				}
				if (controls.UI_RIGHT_P)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
					curTime += 1000;
					holdTime = 0;
				}

				if(controls.UI_LEFT || controls.UI_RIGHT)
				{
					holdTime += elapsed;
					if(holdTime > 0.5)
					{
						curTime += 45000 * elapsed * (controls.UI_LEFT ? -1 : 1);
					}

					if(curTime >= FlxG.sound.music.length) curTime -= FlxG.sound.music.length;
					else if(curTime < 0) curTime += FlxG.sound.music.length;
					updateSkipTimeText();
				}
		}

		if (controls.ACCEPT && (cantUnpause <= 0 || !controls.controllerMode))
		{
			if (menuItems == difficultyChoices)
			{
				var songLowercase:String = Paths.formatToSongPath(PlayState.SONG.song);
				var poop:String = Highscore.formatSong(songLowercase, curSelected);
				try
				{
					if(menuItems.length - 1 != curSelected && difficultyChoices.contains(daSelected))
					{
						Song.loadFromJson(poop, songLowercase);
						PlayState.storyDifficulty = curSelected;
						MusicBeatState.resetState();
						FlxG.sound.music.volume = 0;
						PlayState.changedDifficulty = true;
						PlayState.chartingMode = false;
						return;
					}
				}
				catch(e:haxe.Exception)
				{
					trace('ERROR! ${e.message}');
	
					var errorStr:String = e.message;
					if(errorStr.startsWith('[lime.utils.Assets] ERROR:')) errorStr = 'Missing file: ' + errorStr.substring(errorStr.indexOf(songLowercase), errorStr.length-1); //Missing chart
					else errorStr += '\n\n' + e.stack;

					missingText.text = 'ERROR WHILE LOADING CHART:\n$errorStr';
					missingText.screenCenter(Y);
					missingText.visible = true;
					missingTextBG.visible = true;
					FlxG.sound.play(Paths.sound('cancelMenu'));

					super.update(elapsed);
					return;
				}


				menuItems = menuItemsOG;
				regenMenu();
			}

			switch (daSelected)
			{
				case "Resume":
					Paths.clearUnusedMemory();
					close();
				case 'Change Difficulty':
					menuItems = difficultyChoices;
					deleteSkipTimeText();
					regenMenu();
				case 'Toggle Practice Mode':
					PlayState.instance.practiceMode = !PlayState.instance.practiceMode;
					PlayState.changedDifficulty = true;
					practiceText.visible = PlayState.instance.practiceMode;
				case "Restart Song":
					restartSong();
				case 'Chart Editor':
					PlayState.instance.openChartEditor();
				case "Leave Charting Mode":
					restartSong();
					PlayState.chartingMode = false;
				case 'Skip Time':
					if(curTime < Conductor.songPosition)
					{
						PlayState.startOnTime = curTime;
						restartSong(true);
					}
					else
					{
						if (curTime != Conductor.songPosition)
						{
							PlayState.instance.clearNotesBefore(curTime);
							PlayState.instance.setSongTime(curTime);
						}
						close();
					}
				case 'End Song':
					close();
					PlayState.instance.notes.clear();
					PlayState.instance.unspawnNotes = [];
					PlayState.instance.finishSong(true);
				case 'Toggle Botplay':
					PlayState.instance.cpuControlled = !PlayState.instance.cpuControlled;
					PlayState.changedDifficulty = true;
					PlayState.instance.botplayTxt.visible = PlayState.instance.cpuControlled;
					PlayState.instance.botplayTxt.alpha = 1;
					PlayState.instance.botplaySine = 0;
				case 'Options':
					PlayState.instance.paused = true; // For lua
					PlayState.instance.vocals.volume = 0;
					PlayState.instance.canResync = false;
					MusicBeatState.switchState(new OptionsState());
					if(ClientPrefs.data.pauseMusic != 'None')
					{
						FlxG.sound.playMusic(Paths.music(Paths.formatToSongPath(ClientPrefs.data.pauseMusic)), pauseMusic.volume);
						FlxTween.tween(FlxG.sound.music, {volume: 1}, 0.8);
						FlxG.sound.music.time = pauseMusic.time;
					}
					OptionsState.onPlayState = true;
				case "Exit to menu":
					#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end
					PlayState.deathCounter = 0;
					PlayState.seenCutscene = false;

					PlayState.instance.canResync = false;
					Mods.loadTopMod();
					if(PlayState.isStoryMode)
						MusicBeatState.switchState(new StoryMenuState());
					else 
						MusicBeatState.switchState(new FreeplayState());

					FlxG.sound.playMusic(Paths.music('freakyMenu'));
					PlayState.changedDifficulty = false;
					PlayState.chartingMode = false;
					FlxG.camera.followLerp = 0;
			}
		}

		if (touchPad == null) //sometimes it dosent add the tpad, hopefully this fixes it
		{
			addTouchPad(PlayState.chartingMode ? 'LEFT_FULL' : 'UP_DOWN', 'A');
			addTouchPadCamera();
		}
	}

	function deleteSkipTimeText()
	{
		if(skipTimeText != null)
		{
			skipTimeText.kill();
			remove(skipTimeText);
			skipTimeText.destroy();
		}
		skipTimeText = null;
		skipTimeTracker = null;
	}

	public static function restartSong(noTrans:Bool = false)
	{
		PlayState.instance.paused = true; // For lua
		FlxG.sound.music.volume = 0;
		PlayState.instance.vocals.volume = 0;

		if(noTrans)
		{
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
		}
		MusicBeatState.resetState();
	}

	override function destroy()
	{
		pauseMusic.destroy();
		if (pauseCam != null && FlxG.cameras.list.contains(pauseCam))
			FlxG.cameras.remove(pauseCam, true);
		pauseCam = null;
		super.destroy();
	}

	function changeSelection(change:Int = 0):Void
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, menuItems.length - 1);
		for (num => item in grpMenuShit.members)
		{
			if (num == curSelected && item == skipTimeTracker)
			{
				curTime = Math.max(0, Conductor.songPosition);
				updateSkipTimeText();
			}
		}
		missingText.visible = false;
		missingTextBG.visible = false;
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}

	function regenMenu():Void {
		while (grpMenuShit.members.length > 0)
		{
			var obj:FlxText = grpMenuShit.members[0];
			grpMenuShit.remove(obj, true);
			obj.destroy();
		}
		itemW = [];

		for (num => str in menuItems) {
			var item:FlxText = new FlxText(0, 0, 0, Language.getPhrase('pause_$str', str).toUpperCase(), 34);
			item.setFormat(fontPath, 34, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			item.borderSize = 2;
			item.scrollFactor.set();
			itemW.push(item.width);
			grpMenuShit.add(item);

			if(str == 'Skip Time')
			{
				skipTimeText = new FlxText(0, 0, 0, '', 40);
				skipTimeText.setFormat(fontPath, 40, accent, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				skipTimeText.scrollFactor.set();
				skipTimeText.borderSize = 2;
				skipTimeTracker = item;
				add(skipTimeText);

				updateItems(0);
				updateSkipTextStuff();
				updateSkipTimeText();
			}
		}
		curSelected = 0;
		lerpSelected = 0;
		changeSelection();
	}

	// Lista sobre el panel; el item elegido queda siempre en la barra central
	function updateItems(elapsed:Float):Void
	{
		lerpSelected = FlxMath.lerp(curSelected, lerpSelected, Math.exp(-elapsed * 12));
		for (i => item in grpMenuShit.members)
		{
			var d:Float = i - lerpSelected;
			var ad:Float = Math.abs(d);
			item.visible = ad < 4.5;
			if (!item.visible) continue;

			var cy:Float = H / 2 + d * 62;
			var baseX:Float = Math.max(24, 70 - 3 * d * d) + 12 * Math.max(0, 1 - ad) + slide;
			var avail:Float = edgeAt(cy) - baseX - slide - 34;
			var sc:Float = Math.max(0.5, Math.min(1, avail / itemW[i]));
			item.scale.set(sc, sc);
			item.updateHitbox();
			item.x = baseX;
			item.y = cy - item.height / 2;
			item.alpha = Math.max(0.1, 1 - Math.min(ad, 1) * 0.45 - Math.max(0, ad - 1) * 0.14) * introT;
			item.color = ad < 0.5 ? FlxColor.WHITE : 0xFFA9BCD0;
		}
	}

	function updateSkipTextStuff()
	{
		if(skipTimeText == null || skipTimeTracker == null) return;

		skipTimeText.x = edgeAt(skipTimeTracker.y) + 64;
		skipTimeText.y = skipTimeTracker.y + skipTimeTracker.height / 2 - skipTimeText.height / 2;
		skipTimeText.visible = (grpMenuShit.members.indexOf(skipTimeTracker) == curSelected);
	}

	function updateSkipTimeText()
		skipTimeText.text = FlxStringUtil.formatTime(Math.max(0, Math.floor(curTime / 1000)), false) + ' / ' + FlxStringUtil.formatTime(Math.max(0, Math.floor(FlxG.sound.music.length / 1000)), false);
}
