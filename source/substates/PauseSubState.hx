package substates;

import backend.WeekData;
import backend.Highscore;
import backend.Song;

import flixel.FlxCamera;
import flixel.math.FlxPoint;
import flixel.util.FlxSpriteUtil;
import flixel.util.FlxStringUtil;

import openfl.utils.AssetType;
import mobile.backend.MobileScaleMode;

import states.StoryMenuState;
import states.FreeplayState;
import options.OptionsState;

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

	// --- Diseño NixerEngine ---
	var pauseCam:FlxCamera;
	var W:Float = 1280; // ancho real de la pantalla (incluye pantalla ancha)
	var edgeTop:Float = 400;    // x del borde diagonal arriba
	var edgeBottom:Float = 240; // x del borde diagonal abajo
	var fontPath:String;

	public static var songName:String = null;

	inline function edgeAt(y:Float):Float
		return edgeTop + (edgeBottom - edgeTop) * (y / FlxG.height);

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

		// Ancho real de la pantalla (16:9 = 1280, más ancho si hay pantalla ancha)
		W = FlxG.width + MobileScaleMode.gameCutoutSize.x * 2;
		var H:Float = FlxG.height;
		var imgScale:Float = H / 1080; // los PNG de diseño miden 2164x1080

		fontPath = Paths.fileExists('fonts/freeplay.ttf', AssetType.FONT) ? Paths.font('freeplay.ttf') : Paths.font('vcr.ttf');

		// Cámara propia, tan ancha como la pantalla
		pauseCam = new FlxCamera(0, 0, Std.int(W), Std.int(H));
		pauseCam.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(pauseCam, false);

		// ---------- Fondo (assets/images/freeplay/bg.png) ----------
		var bg:FlxSprite;
		var bgAlpha:Float;
		if (Paths.fileExists('images/freeplay/bg.png', AssetType.IMAGE))
		{
			bg = new FlxSprite().loadGraphic(Paths.image('freeplay/bg'));
			bg.antialiasing = ClientPrefs.data.antialiasing;
			var bgScale:Float = Math.max(W / bg.width, H / bg.height);
			bg.setGraphicSize(Std.int(bg.width * bgScale));
			bg.updateHitbox();
			bg.setPosition((W - bg.width) / 2, (H - bg.height) / 2);
			bgAlpha = 0.92;
		}
		else
		{
			bg = new FlxSprite().makeGraphic(Std.int(W), Std.int(H), FlxColor.BLACK);
			bgAlpha = 0.6;
		}
		bg.alpha = 0;
		bg.scrollFactor.set();
		add(bg);

		// ---------- Panel izquierdo (detrás de las opciones) ----------
		var leftPanel:FlxSprite;
		if (Paths.fileExists('images/freeplay/panel_left.png', AssetType.IMAGE))
		{
			leftPanel = new FlxSprite().loadGraphic(Paths.image('freeplay/panel_left'));
			leftPanel.antialiasing = ClientPrefs.data.antialiasing;
			leftPanel.scale.set(imgScale, imgScale);
			leftPanel.updateHitbox();
			leftPanel.setPosition(0, 0);
			edgeTop = 675 * imgScale;
			edgeBottom = 410 * imgScale;
		}
		else
		{
			leftPanel = new FlxSprite().makeGraphic(420, Std.int(H), FlxColor.TRANSPARENT, true);
			FlxSpriteUtil.drawPolygon(leftPanel, [
				FlxPoint.get(0, 0), FlxPoint.get(400, 0),
				FlxPoint.get(240, H), FlxPoint.get(0, H)
			], 0xFF000000);
			FlxSpriteUtil.drawLine(leftPanel, 400, 0, 240, H, {thickness: 8, color: 0xFF3A1BB5});
			edgeTop = 400;
			edgeBottom = 240;
		}
		leftPanel.alpha = 0;
		leftPanel.scrollFactor.set();
		add(leftPanel);

		// ---------- Panel superior derecho (info de la canción) ----------
		var rightPanel:FlxSprite;
		var panelTextX:Float;
		var panelTextW:Float;
		if (Paths.fileExists('images/freeplay/panel_right.png', AssetType.IMAGE))
		{
			rightPanel = new FlxSprite().loadGraphic(Paths.image('freeplay/panel_right'));
			rightPanel.antialiasing = ClientPrefs.data.antialiasing;
			rightPanel.scale.set(imgScale, imgScale);
			rightPanel.updateHitbox();
			rightPanel.setPosition(W - rightPanel.width, 0);
			panelTextX = W - (2164 - 1490) * imgScale;
		}
		else
		{
			var panelW:Float = 450;
			var panelH:Float = 72;
			rightPanel = new FlxSprite(W - panelW, 0).makeGraphic(Std.int(panelW), Std.int(panelH), FlxColor.TRANSPARENT, true);
			FlxSpriteUtil.drawPolygon(rightPanel, [
				FlxPoint.get(0, 0), FlxPoint.get(panelW, 0),
				FlxPoint.get(panelW, panelH), FlxPoint.get(38, panelH)
			], 0xFF000000);
			FlxSpriteUtil.drawLine(rightPanel, 0, 0, 38, panelH, {thickness: 4, color: FlxColor.WHITE});
			FlxSpriteUtil.drawLine(rightPanel, 38, panelH - 2, panelW, panelH - 2, {thickness: 4, color: FlxColor.WHITE});
			panelTextX = W - panelW + 54;
		}
		panelTextW = W - panelTextX - 20;
		rightPanel.alpha = 0;
		rightPanel.scrollFactor.set();
		add(rightPanel);

		// Dificultad SIEMPRE en inglés (nombre original de la lista, sin traducir)
		var diffIndex:Int = Std.int(Math.max(0, Math.min(Difficulty.list.length - 1, PlayState.storyDifficulty)));
		var diffName:String = Difficulty.list[diffIndex];
		diffName = diffName.charAt(0).toUpperCase() + diffName.substr(1);

		var levelInfo:FlxText = new FlxText(panelTextX, 6, 0, PlayState.SONG.song, 26);
		levelInfo.setFormat(fontPath, 26, FlxColor.WHITE, LEFT);
		levelInfo.scrollFactor.set();
		fitText(levelInfo, panelTextW);
		add(levelInfo);

		var infoLine:String = 'Difficulty: ' + diffName + '   ' + Language.getPhrase("blueballed", "Blueballed: {1}", [PlayState.deathCounter]);
		var levelDifficulty:FlxText = new FlxText(panelTextX, 38, 0, infoLine, 20);
		levelDifficulty.setFormat(fontPath, 20, FlxColor.WHITE, LEFT);
		levelDifficulty.scrollFactor.set();
		fitText(levelDifficulty, panelTextW);
		add(levelDifficulty);

		// Modo práctica / charting
		practiceText = new FlxText(20, 80, 0, Language.getPhrase("Practice Mode").toUpperCase(), 32);
		practiceText.scrollFactor.set();
		practiceText.setFormat(fontPath, 32, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		practiceText.x = W - (practiceText.width + 20);
		practiceText.visible = PlayState.instance.practiceMode;
		add(practiceText);

		var chartingText:FlxText = new FlxText(20, 0, 0, Language.getPhrase("Charting Mode").toUpperCase(), 32);
		chartingText.scrollFactor.set();
		chartingText.setFormat(fontPath, 32, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		chartingText.x = W - (chartingText.width + 20);
		chartingText.y = H - (chartingText.height + 20);
		chartingText.visible = PlayState.chartingMode;
		add(chartingText);

		levelInfo.alpha = 0;
		levelDifficulty.alpha = 0;

		FlxTween.tween(bg, {alpha: bgAlpha}, 0.4, {ease: FlxEase.quartInOut});
		FlxTween.tween(leftPanel, {alpha: 1}, 0.3, {ease: FlxEase.quartInOut});
		FlxTween.tween(rightPanel, {alpha: 1}, 0.3, {ease: FlxEase.quartInOut});
		FlxTween.tween(levelInfo, {alpha: 1}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.2});
		FlxTween.tween(levelDifficulty, {alpha: 1}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.3});

		grpMenuShit = new FlxTypedGroup<FlxText>();
		add(grpMenuShit);

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

		regenMenu();
		updateItems(0);
		cameras = [pauseCam];

		addTouchPad(menuItems.contains('Skip Time') ? 'LEFT_FULL' : 'UP_DOWN', 'A');
		addTouchPadCamera();

		super.create();
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
			item.alpha = 0.55;
			if (num == curSelected)
			{
				item.alpha = 1;
				if(item == skipTimeTracker)
				{
					curTime = Math.max(0, Conductor.songPosition);
					updateSkipTimeText();
				}
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
			var item:FlxText = new FlxText(0, 0, 0, Language.getPhrase('pause_$str', str), 34);
			item.setFormat(fontPath, 34, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			item.borderSize = 2;
			item.scrollFactor.set();
			itemW.push(item.width);
			grpMenuShit.add(item);

			if(str == 'Skip Time')
			{
				skipTimeText = new FlxText(0, 0, 0, '', 40);
				skipTimeText.setFormat(fontPath, 40, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
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

	// Lista en curva sobre el panel izquierdo; el texto se achica si no cabe antes del borde
	function updateItems(elapsed:Float):Void
	{
		lerpSelected = FlxMath.lerp(curSelected, lerpSelected, Math.exp(-elapsed * 12));
		for (i => item in grpMenuShit.members)
		{
			var d:Float = i - lerpSelected;
			item.visible = Math.abs(d) < 5.5;
			if (!item.visible) continue;

			var cy:Float = FlxG.height / 2 + d * 68;
			var baseX:Float = Math.max(24, 70 - 3 * d * d); // nunca se sale por la izquierda
			var avail:Float = edgeAt(cy) - baseX - 30;
			var sc:Float = Math.max(0.5, Math.min(1, avail / itemW[i]));
			item.scale.set(sc, sc);
			item.updateHitbox();
			item.x = baseX;
			item.y = cy - item.height / 2;
		}
	}
	
	function updateSkipTextStuff()
	{
		if(skipTimeText == null || skipTimeTracker == null) return;

		skipTimeText.x = edgeAt(skipTimeTracker.y) + 50;
		skipTimeText.y = skipTimeTracker.y + skipTimeTracker.height / 2 - skipTimeText.height / 2;
		skipTimeText.visible = (skipTimeTracker.alpha >= 1);
	}

	function updateSkipTimeText()
		skipTimeText.text = FlxStringUtil.formatTime(Math.max(0, Math.floor(curTime / 1000)), false) + ' / ' + FlxStringUtil.formatTime(Math.max(0, Math.floor(FlxG.sound.music.length / 1000)), false);
}
