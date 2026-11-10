package states;

import backend.WeekData;
import backend.Highscore;
import backend.Song;

import objects.HealthIcon;
import objects.MusicPlayer;

import options.GameplayChangersSubstate;
import substates.ResetScoreSubState;

import flixel.math.FlxMath;
import flixel.FlxObject;
import flixel.math.FlxPoint;
import flixel.util.FlxDestroyUtil;
import flixel.util.FlxSpriteUtil;

import openfl.utils.AssetType;
import mobile.backend.MobileScaleMode;

import openfl.utils.Assets;

import haxe.Json;

class FreeplayState extends MusicBeatState
{
	var songs:Array<SongMetadata> = [];

	var selector:FlxText;
	private static var curSelected:Int = 0;
	var lerpSelected:Float = 0;
	var curDifficulty:Int = -1;
	private static var lastDifficultyName:String = Difficulty.getDefault();

	var scoreBG:FlxSprite;
	var scoreText:FlxText;
	var diffText:FlxText;
	var lerpScore:Int = 0;
	var lerpRating:Float = 0;
	var intendedScore:Int = 0;
	var intendedRating:Float = 0;

	private var grpSongs:FlxTypedGroup<Alphabet>;
	private var curPlaying:Bool = false;

	private var iconArray:Array<HealthIcon> = [];

	var bg:FlxSprite;
	var intendedColor:Int;

	var missingTextBG:FlxSprite;
	var missingText:FlxText;

	var bottomString:String;
	var bottomText:FlxText;
	var bottomBG:FlxSprite;

	var player:MusicPlayer;

	// --- Diseño NixerEngine ---
	var W:Float = 1280; // ancho real de la pantalla (incluye pantalla ancha)
	var artSprite:FlxSprite;
	var artName:String = '';
	var leftPanel:FlxSprite;
	var composerText:FlxText;
	var songTexts:Array<FlxText> = [];
	var songTextW:Array<Float> = [];
	var artBG:FlxSprite;
	var panelTextX:Float = 0;
	var composerX:Float = 0;
	var scoreRight:Float = 0;
	var checker:FlxSprite;
	var mic:FlxSprite;

	// Los PNG de assets/shared/images/freeplay/ están a 720 de alto.
	static inline final DESIGN_H:Float = 720;
	static inline final SEL_Y:Float = 291;       // y del centro de la canción elegida
	static inline final ROW_STEP:Float = 150;    // separación con las canciones vecinas
	static inline final ROW_STEP_FAR:Float = 118; // separación entre las más lejanas
	static inline final ICON_CX:Float = 337;     // x del centro del icono elegido
	static inline final ICON_CURVE:Float = 14.7; // cuánto se curva la lista
	static inline final MIC_X:Float = 393;
	static inline final MIC_Y:Float = 254;

	inline function pin(o:FlxObject):Void
		o.scrollFactor.set();

	override function create()
	{
		persistentUpdate = true;
		PlayState.isStoryMode = false;
		WeekData.reloadWeekFiles(false);

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		final accept:String = (controls.mobileC) ? "A" : "ACCEPT";
		final reject:String = (controls.mobileC) ? "B" : "BACK";

		if(WeekData.weeksList.length < 1)
		{
			showEmptyError(accept, reject, "NO WEEKS ADDED FOR FREEPLAY");
			return;
		}

		for (i in 0...WeekData.weeksList.length)
		{
			if(weekIsLocked(WeekData.weeksList[i])) continue;

			var leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			if(leWeek == null || leWeek.songs == null) continue;

			WeekData.setDirectoryFromWeek(leWeek);
			for (song in leWeek.songs)
			{
				var colors:Array<Int> = song[2];
				if(colors == null || colors.length < 3)
				{
					colors = [146, 113, 253];
				}
				var songData:Array<Dynamic> = song;
				var songComposer:String = (songData.length > 3 && songData[3] != null) ? Std.string(songData[3]) : '';
				addSong(song[0], i, song[1], FlxColor.fromRGB(colors[0], colors[1], colors[2]), songComposer);
			}
		}
		Mods.loadTopMod();

		if(songs.length < 1)
		{
			showEmptyError(accept, reject, "NO SONGS FOUND FOR FREEPLAY");
			return;
		}

		// Ancho real de la pantalla (16:9 = 1280, más ancho si hay pantalla ancha)
		W = FlxG.width + MobileScaleMode.gameCutoutSize.x * 2;
		var H:Float = FlxG.height;

		var fontPath:String = Paths.font('vcr.ttf');
		if (Paths.fileExists('fonts/freeplay.otf', AssetType.FONT)) fontPath = Paths.font('freeplay.otf');
		else if (Paths.fileExists('fonts/freeplay.ttf', AssetType.FONT)) fontPath = Paths.font('freeplay.ttf');

		var imgScale:Float = H / DESIGN_H;
		var aa:Bool = ClientPrefs.data.antialiasing;

		// ---------- Fondo (images/freeplay/bg.png) ----------
		var hasBgPng:Bool = Paths.fileExists('images/freeplay/bg.png', AssetType.IMAGE);
		artBG = new FlxSprite().loadGraphic(Paths.image(hasBgPng ? 'freeplay/bg' : 'menuDesat'));
		artBG.antialiasing = aa;
		var bgScale:Float = Math.max(W / artBG.width, H / artBG.height);
		artBG.setGraphicSize(Std.int(artBG.width * bgScale));
		artBG.updateHitbox();
		artBG.setPosition((W - artBG.width) / 2, (H - artBG.height) / 2);
		pin(artBG);
		add(artBG);

		// El fondo (blanco/gris) se pinta directamente con el color de la canción,
		// sin ninguna capa encima. `bg` apunta al mismo sprite para el tween de color.
		bg = artBG;

		// ---------- Cuadros (images/freeplay/checker.png, con transparencia) ----------
		if (Paths.fileExists('images/freeplay/checker.png', AssetType.IMAGE))
		{
			checker = new FlxSprite().loadGraphic(Paths.image('freeplay/checker'));
			checker.antialiasing = aa;
			var cs:Float = Math.max(W / checker.width, H / checker.height);
			checker.setGraphicSize(Std.int(checker.width * cs));
			checker.updateHitbox();
			checker.setPosition((W - checker.width) / 2, (H - checker.height) / 2);
			pin(checker);
			add(checker);
		}

		// ---------- Arte del personaje (derecha) ----------
		artSprite = new FlxSprite();
		artSprite.antialiasing = aa;
		artSprite.visible = false;
		pin(artSprite);
		add(artSprite);

		// ---------- Panel izquierdo (images/freeplay/panel_left.png) ----------
		if (Paths.fileExists('images/freeplay/panel_left.png', AssetType.IMAGE))
		{
			leftPanel = new FlxSprite().loadGraphic(Paths.image('freeplay/panel_left'));
			leftPanel.antialiasing = aa;
			leftPanel.scale.set(imgScale, imgScale);
			leftPanel.updateHitbox();
			leftPanel.setPosition(0, 0);
		}
		else
		{
			leftPanel = new FlxSprite().makeGraphic(420, Std.int(H), FlxColor.TRANSPARENT, true);
			FlxSpriteUtil.drawPolygon(leftPanel, [
				FlxPoint.get(0, 0), FlxPoint.get(400, 0),
				FlxPoint.get(240, H), FlxPoint.get(0, H)
			], 0xFF000000);
			FlxSpriteUtil.drawLine(leftPanel, 400, 0, 240, H, {thickness: 8, color: 0xFF3A1BB5});
		}
		pin(leftPanel);
		add(leftPanel);

		// ---------- Micrófono (images/freeplay/mic.png), fijo junto a la canción elegida ----------
		if (Paths.fileExists('images/freeplay/mic.png', AssetType.IMAGE))
		{
			mic = new FlxSprite().loadGraphic(Paths.image('freeplay/mic'));
			mic.antialiasing = aa;
			mic.scale.set(imgScale, imgScale);
			mic.updateHitbox();
			mic.setPosition(MIC_X * imgScale, MIC_Y * imgScale);
			pin(mic);
			add(mic);
		}

		grpSongs = new FlxTypedGroup<Alphabet>(); // se deja vacío por compatibilidad

		// ---------- Canciones + iconos ----------
		for (i in 0...songs.length)
		{
			var songText:FlxText = new FlxText(0, 0, 0, songs[i].songName, 44); // ↑ tamaño base aumentado
			songText.setFormat(fontPath, 44, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			songText.borderSize = 2;
			songText.antialiasing = ClientPrefs.data.antialiasing;
			songText.visible = songText.active = false;
			pin(songText);
			songTextW.push(songText.width);
			songTexts.push(songText);
			add(songText);

			Mods.currentModDirectory = songs[i].folder;
			var icon:HealthIcon = new HealthIcon(songs[i].songCharacter);
			icon.scale.set(0.7, 0.7);
			icon.updateHitbox();
			icon.visible = icon.active = false;
			pin(icon);
			iconArray.push(icon);
			add(icon);
		}
		WeekData.setDirectoryFromWeek();

		// ---------- Cabecera superior derecha (images/freeplay/panel_right.png) ----------
		if (Paths.fileExists('images/freeplay/panel_right.png', AssetType.IMAGE))
		{
			scoreBG = new FlxSprite().loadGraphic(Paths.image('freeplay/panel_right'));
			scoreBG.antialiasing = aa;
			scoreBG.scale.set(imgScale, imgScale);
			scoreBG.updateHitbox();
			scoreBG.setPosition(W - scoreBG.width, 0);
			panelTextX = scoreBG.x + 49 * imgScale;
			composerX = scoreBG.x + 67 * imgScale;
			scoreRight = W - 70 * imgScale;
		}
		else
		{
			var panelW:Float = 450;
			var panelH:Float = 72;
			scoreBG = new FlxSprite(W - panelW, 0).makeGraphic(Std.int(panelW), Std.int(panelH), FlxColor.TRANSPARENT, true);
			FlxSpriteUtil.drawPolygon(scoreBG, [
				FlxPoint.get(0, 0), FlxPoint.get(panelW, 0),
				FlxPoint.get(panelW, panelH), FlxPoint.get(38, panelH)
			], 0xFF000000);
			FlxSpriteUtil.drawLine(scoreBG, 0, 0, 38, panelH, {thickness: 4, color: FlxColor.WHITE});
			FlxSpriteUtil.drawLine(scoreBG, 38, panelH - 2, panelW, panelH - 2, {thickness: 4, color: FlxColor.WHITE});
			panelTextX = W - panelW + 54;
			composerX = panelTextX;
			scoreRight = W - 20;
		}
		pin(scoreBG);
		add(scoreBG);

		diffText = new FlxText(panelTextX, 9, 0, "", 26);
		diffText.setFormat(fontPath, 26, FlxColor.WHITE, LEFT);
		pin(diffText);
		add(diffText);

		scoreText = new FlxText(0, 9, 0, "", 26);
		scoreText.setFormat(fontPath, 26, FlxColor.WHITE, RIGHT);
		pin(scoreText);
		add(scoreText);

		composerText = new FlxText(composerX, 38, 0, "", 26);
		composerText.setFormat(fontPath, 26, FlxColor.WHITE, LEFT);
		pin(composerText);
		add(composerText);

		// ---------- Error de chart ----------
		missingTextBG = new FlxSprite().makeGraphic(Std.int(W), Std.int(H), FlxColor.BLACK);
		missingTextBG.alpha = 0.6;
		missingTextBG.visible = false;
		pin(missingTextBG);
		add(missingTextBG);

		missingText = new FlxText(50, 0, W - 100, '', 24);
		missingText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		missingText.scrollFactor.set();
		missingText.visible = false;
		add(missingText);

		if(curSelected >= songs.length) curSelected = 0;
		bg.color = songs[curSelected].color;
		intendedColor = bg.color;
		lerpSelected = curSelected;

		curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(lastDifficultyName)));

		// ---------- Barra inferior ----------
		bottomBG = new FlxSprite(0, H - 26).makeGraphic(Std.int(W), 26, 0xFF000000);
		bottomBG.alpha = 0.6;
		pin(bottomBG);
		add(bottomBG);

		final space:String = (controls.mobileC) ? "X" : "SPACE";
		final control:String = (controls.mobileC) ? "C" : "CTRL";
		final reset:String = (controls.mobileC) ? "Y" : "RESET";

		var leText:String = Language.getPhrase("freeplay_tip", "Press {1} to listen to the Song / Press {2} to open the Gameplay Changers Menu / Press {3} to Reset your Score and Accuracy.", [space, control, reset]);
		bottomString = leText;
		var size:Int = 16;
		bottomText = new FlxText(bottomBG.x, bottomBG.y + 4, W, leText, size);
		bottomText.setFormat(Paths.font("vcr.ttf"), size, FlxColor.WHITE, CENTER);
		bottomText.scrollFactor.set();
		add(bottomText);

		player = new MusicPlayer(this);
		add(player);

		changeSelection();
		updateTexts();

		addTouchPad('LEFT_FULL', 'A_B_X_Y'); // ← sin C ni Z
		super.create();
	}

	function showEmptyError(accept:String, reject:String, title:String):Void
	{
		FlxTransitionableState.skipNextTransIn = true;
		persistentUpdate = false;
		MusicBeatState.switchState(new states.ErrorState(title + "\n\nPress " + accept + " to go to the Week Editor Menu.\nPress " + reject + " to return to Main Menu.",
			function() MusicBeatState.switchState(new states.editors.WeekEditorState()),
			function() MusicBeatState.switchState(new states.MainMenuState())));
	}

	override function closeSubState()
	{
		changeSelection(0, false);
		persistentUpdate = true;
		super.closeSubState();
		removeTouchPad();
		addTouchPad('LEFT_FULL', 'A_B_X_Y'); // ← sin C ni Z
	}

	public function addSong(songName:String, weekNum:Int, songCharacter:String, color:Int, composer:String = '')
	{
		var meta:SongMetadata = new SongMetadata(songName, weekNum, songCharacter, color);
		meta.composer = composer;
		songs.push(meta);
	}

	function weekIsLocked(name:String):Bool
	{
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		if(leWeek == null) return true; // semana borrada: se salta
		return (!leWeek.startUnlocked && leWeek.weekBefore.length > 0 && (!StoryMenuState.weekCompleted.exists(leWeek.weekBefore) || !StoryMenuState.weekCompleted.get(leWeek.weekBefore)));
	}

	var instPlaying:Int = -1;
	public static var vocals:FlxSound = null;
	public static var opponentVocals:FlxSound = null;
	var holdTime:Float = 0;

	var stopMusicPlay:Bool = false;
	override function update(elapsed:Float)
	{
		if(WeekData.weeksList.length < 1 || songs.length < 1)
			return;

		if (FlxG.sound.music.volume < 0.7)
			FlxG.sound.music.volume += 0.5 * elapsed;

		lerpScore = Math.floor(FlxMath.lerp(intendedScore, lerpScore, Math.exp(-elapsed * 24)));
		lerpRating = FlxMath.lerp(intendedRating, lerpRating, Math.exp(-elapsed * 12));

		if (Math.abs(lerpScore - intendedScore) <= 10)
			lerpScore = intendedScore;
		if (Math.abs(lerpRating - intendedRating) <= 0.01)
			lerpRating = intendedRating;

		var shiftMult:Int = 1;
		if((FlxG.keys.pressed.SHIFT || touchPad.buttonZ.pressed) && !player.playingMusic) shiftMult = 3;

		if (!player.playingMusic)
		{
			scoreText.text = Language.getPhrase('freeplay_score', 'Score:') + ' ' + lerpScore;
			positionHighscore();
			
			if(songs.length > 1)
			{
				if(FlxG.keys.justPressed.HOME)
				{
					curSelected = 0;
					changeSelection();
					holdTime = 0;	
				}
				else if(FlxG.keys.justPressed.END)
				{
					curSelected = songs.length - 1;
					changeSelection();
					holdTime = 0;	
				}
				if (controls.UI_UP_P)
				{
					changeSelection(-shiftMult);
					holdTime = 0;
				}
				if (controls.UI_DOWN_P)
				{
					changeSelection(shiftMult);
					holdTime = 0;
				}

				if(controls.UI_DOWN || controls.UI_UP)
				{
					var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
					holdTime += elapsed;
					var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);

					if(holdTime > 0.5 && checkNewHold - checkLastHold > 0)
						changeSelection((checkNewHold - checkLastHold) * (controls.UI_UP ? -shiftMult : shiftMult));
				}

				if(FlxG.mouse.wheel != 0)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.2);
					changeSelection(-shiftMult * FlxG.mouse.wheel, false);
				}
			}

			if (controls.UI_LEFT_P)
			{
				changeDiff(-1);
				_updateSongLastDifficulty();
			}
			else if (controls.UI_RIGHT_P)
			{
				changeDiff(1);
				_updateSongLastDifficulty();
			}
		}

		if (controls.BACK)
		{
			if (player.playingMusic)
			{
				FlxG.sound.music.stop();
				destroyFreeplayVocals();
				FlxG.sound.music.volume = 0;
				instPlaying = -1;

				player.playingMusic = false;
				player.switchPlayMusic();

				FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
				FlxTween.tween(FlxG.sound.music, {volume: 1}, 1);
			}
			else 
			{
				persistentUpdate = false;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new MainMenuState());
			}
		}

		// Se quitó la detección de C / CONTROL para abrir Gameplay Changers
		// Ahora solo se puede abrir con el botón correspondiente si lo agregas manualmente
		if(FlxG.keys.justPressed.SPACE || touchPad.buttonX.justPressed)
		{
			if(instPlaying != curSelected && !player.playingMusic)
			{
				destroyFreeplayVocals();
				FlxG.sound.music.volume = 0;

				Mods.currentModDirectory = songs[curSelected].folder;
				var poop:String = Highscore.formatSong(songs[curSelected].songName.toLowerCase(), curDifficulty);
				Song.loadFromJson(poop, songs[curSelected].songName.toLowerCase());
				if (PlayState.SONG.needsVoices)
				{
					vocals = new FlxSound();
					try
					{
						var playerVocals:String = getVocalFromCharacter(PlayState.SONG.player1);
						var loadedVocals = Paths.voices(PlayState.SONG.song, (playerVocals != null && playerVocals.length > 0) ? playerVocals : 'Player');
						if(loadedVocals == null) loadedVocals = Paths.voices(PlayState.SONG.song);
						
						if(loadedVocals != null && loadedVocals.length > 0)
						{
							vocals.loadEmbedded(loadedVocals);
							FlxG.sound.list.add(vocals);
							vocals.persist = vocals.looped = true;
							vocals.volume = 0.8;
							vocals.play();
							vocals.pause();
						}
						else vocals = FlxDestroyUtil.destroy(vocals);
					}
					catch(e:Dynamic)
					{
						vocals = FlxDestroyUtil.destroy(vocals);
					}
					
					opponentVocals = new FlxSound();
					try
					{
						//trace('please work...');
						var oppVocals:String = getVocalFromCharacter(PlayState.SONG.player2);
						var loadedVocals = Paths.voices(PlayState.SONG.song, (oppVocals != null && oppVocals.length > 0) ? oppVocals : 'Opponent');
						
						if(loadedVocals != null && loadedVocals.length > 0)
						{
							opponentVocals.loadEmbedded(loadedVocals);
							FlxG.sound.list.add(opponentVocals);
							opponentVocals.persist = opponentVocals.looped = true;
							opponentVocals.volume = 0.8;
							opponentVocals.play();
							opponentVocals.pause();
							//trace('yaaay!!');
						}
						else opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
					}
					catch(e:Dynamic)
					{
						//trace('FUUUCK');
						opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
					}
				}

				FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 0.8);
				FlxG.sound.music.pause();
				instPlaying = curSelected;

				player.playingMusic = true;
				player.curTime = 0;
				player.switchPlayMusic();
				player.pauseOrResume(true);
			}
			else if (instPlaying == curSelected && player.playingMusic)
			{
				player.pauseOrResume(!player.playing);
			}
		}
		else if (controls.ACCEPT && !player.playingMusic)
		{
			persistentUpdate = false;
			var songLowercase:String = Paths.formatToSongPath(songs[curSelected].songName);
			var poop:String = Highscore.formatSong(songLowercase, curDifficulty);

			try
			{
				Song.loadFromJson(poop, songLowercase);
				PlayState.isStoryMode = false;
				PlayState.storyDifficulty = curDifficulty;

				trace('CURRENT WEEK: ' + WeekData.getWeekFileName());
			}
			catch(e:haxe.Exception)
			{
				trace('ERROR! ${e.message}');

				var errorStr:String = e.message;
				if(errorStr.contains('There is no TEXT asset with an ID of')) errorStr = 'Missing file: ' + errorStr.substring(errorStr.indexOf(songLowercase), errorStr.length-1); //Missing chart
				else errorStr += '\n\n' + e.stack;

				missingText.text = 'ERROR WHILE LOADING CHART:\n$errorStr';
				missingText.screenCenter(Y);
				missingText.visible = true;
				missingTextBG.visible = true;
				FlxG.sound.play(Paths.sound('cancelMenu'));

				updateTexts(elapsed);
				super.update(elapsed);
				return;
			}

			@:privateAccess
			if(PlayState._lastLoadedModDirectory != Mods.currentModDirectory)
			{
				trace('CHANGED MOD DIRECTORY, RELOADING STUFF');
				Paths.freeGraphicsFromMemory();
			}
			LoadingState.prepareToSong();
			LoadingState.loadAndSwitchState(new PlayState());
			#if !SHOW_LOADING_SCREEN FlxG.sound.music.stop(); #end
			stopMusicPlay = true;

			destroyFreeplayVocals();
			#if (MODS_ALLOWED && DISCORD_ALLOWED)
			DiscordClient.loadModRPC();
			#end
		}
		else if((controls.RESET || touchPad.buttonY.justPressed) && !player.playingMusic)
		{
			persistentUpdate = false;
			openSubState(new ResetScoreSubState(songs[curSelected].songName, curDifficulty, songs[curSelected].songCharacter));
			removeTouchPad();
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}

		updateTexts(elapsed);
		super.update(elapsed);
	}
	
	function getVocalFromCharacter(char:String)
	{
		try
		{
			var path:String = Paths.getPath('characters/$char.json', TEXT);
			#if MODS_ALLOWED
			var character:Dynamic = Json.parse(File.getContent(path));
			#else
			var character:Dynamic = Json.parse(Assets.getText(path));
			#end
			return character.vocals_file;
		}
		catch (e:Dynamic) {}
		return null;
	}

	public static function destroyFreeplayVocals() {
		if(vocals != null) vocals.stop();
		vocals = FlxDestroyUtil.destroy(vocals);

		if(opponentVocals != null) opponentVocals.stop();
		opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
	}

	function changeDiff(change:Int = 0)
	{
		if (player.playingMusic)
			return;

		curDifficulty = FlxMath.wrap(curDifficulty + change, 0, Difficulty.list.length-1);
		#if !switch
		intendedScore = Highscore.getScore(songs[curSelected].songName, curDifficulty);
		intendedRating = Highscore.getRating(songs[curSelected].songName, curDifficulty);
		#end

		lastDifficultyName = Difficulty.getString(curDifficulty, false);
		var displayDiff:String = Difficulty.getString(curDifficulty);
		var diffLabel:String = Language.getPhrase('freeplay_difficulty', 'Difficulty:');
		if (Difficulty.list.length > 1)
			diffText.text = diffLabel + ' <' + displayDiff + '>';
		else
			diffText.text = diffLabel + displayDiff;

		positionHighscore();
		missingText.visible = false;
		missingTextBG.visible = false;
	}

	function changeSelection(change:Int = 0, playSound:Bool = true)
	{
		if (player.playingMusic)
			return;

		curSelected = FlxMath.wrap(curSelected + change, 0, songs.length-1);
		_updateSongLastDifficulty();
		if(playSound) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		var newColor:Int = songs[curSelected].color;
		if(newColor != intendedColor)
		{
			intendedColor = newColor;
			FlxTween.cancelTweensOf(bg);
			FlxTween.color(bg, 1, bg.color, intendedColor);
		}

		for (num => item in songTexts)
		{
			var icon:HealthIcon = iconArray[num];
			item.alpha = 0.6;
			icon.alpha = 0.6;
			if (num == curSelected)
			{
				item.alpha = 1;
				icon.alpha = 1;
			}
		}

		Mods.currentModDirectory = songs[curSelected].folder;
		PlayState.storyWeek = songs[curSelected].week;
		Difficulty.loadFromWeek();
		
		var savedDiff:String = songs[curSelected].lastDifficulty;
		var lastDiff:Int = Difficulty.list.indexOf(lastDifficultyName);
		if(savedDiff != null && !Difficulty.list.contains(savedDiff) && Difficulty.list.contains(savedDiff))
			curDifficulty = Math.round(Math.max(0, Difficulty.list.indexOf(savedDiff)));
		else if(lastDiff > -1)
			curDifficulty = lastDiff;
		else if(Difficulty.list.contains(Difficulty.getDefault()))
			curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(Difficulty.getDefault())));
		else
			curDifficulty = 0;

		changeDiff();
		_updateSongLastDifficulty();
		updateArt();
		updateComposer();
	}

	inline private function _updateSongLastDifficulty()
		songs[curSelected].lastDifficulty = Difficulty.getString(curDifficulty, false);

	private function positionHighscore()
	{
		diffText.x = panelTextX;
		scoreText.x = scoreRight - scoreText.width;
		composerText.x = composerX;
	}

	// Arte de la derecha: assets/images/freeplay/art/<cancion>.png
	// (o <icono>.png, con el nombre del icono de la canción). Si no existe, no se muestra nada.
	function updateArt():Void
	{
		var songKey:String = 'freeplay/art/' + Paths.formatToSongPath(songs[curSelected].songName);
		var charKey:String = 'freeplay/art/' + songs[curSelected].songCharacter;

		var key:String = null;
		if (Paths.fileExists('images/' + songKey + '.png', AssetType.IMAGE))
			key = songKey;
		else if (Paths.fileExists('images/' + charKey + '.png', AssetType.IMAGE))
			key = charKey;

		if (key == null)
		{
			artName = '';
			FlxTween.cancelTweensOf(artSprite);
			artSprite.visible = false;
			return;
		}
		if (key == artName && artSprite.visible) return;
		artName = key;

		artSprite.loadGraphic(Paths.image(key));
		var sc:Float = (FlxG.height * 1.05) / artSprite.frameHeight;
		artSprite.scale.set(sc, sc);
		artSprite.updateHitbox();
		artSprite.x = W - artSprite.width;
		artSprite.y = FlxG.height - artSprite.height;
		artSprite.visible = true;
		artSprite.alpha = 0;
		FlxTween.cancelTweensOf(artSprite);
		FlxTween.tween(artSprite, {alpha: 1}, 0.25);
	}

	// Compositor: 4.º valor de la canción en el JSON de la week, o assets/data/<cancion>/composer.txt
	function updateComposer():Void
	{
		var composer:String = songs[curSelected].composer;
		if (composer == null || composer.trim().length < 1)
		{
			composer = '???';
			var file:String = 'data/' + Paths.formatToSongPath(songs[curSelected].songName) + '/composer.txt';
			if (Paths.fileExists(file, AssetType.TEXT))
			{
				var content:String = Paths.getTextFromFile(file);
				if (content != null && content.trim().length > 0)
					composer = content.trim().split('\n')[0].trim();
			}
		}
		composerText.text = Language.getPhrase('freeplay_composer', 'Composer:') + ' ' + composer;
	}

	var _drawDistance:Int = 4;
	var _lastVisibles:Array<Int> = [];
	public function updateTexts(elapsed:Float = 0.0)
	{
		lerpSelected = FlxMath.lerp(curSelected, lerpSelected, Math.exp(-elapsed * 9.6));
		for (i in _lastVisibles)
		{
			songTexts[i].visible = songTexts[i].active = false;
			iconArray[i].visible = iconArray[i].active = false;
		}
		_lastVisibles = [];

		var s:Float = FlxG.height / DESIGN_H;
		var min:Int = Math.round(Math.max(0, Math.min(songs.length, lerpSelected - _drawDistance)));
		var max:Int = Math.round(Math.max(0, Math.min(songs.length, lerpSelected + _drawDistance + 1)));
		for (i in min...max)
		{
			var d:Float = i - lerpSelected;
			var ad:Float = Math.abs(d);

			// Altura: las vecinas quedan a ROW_STEP y las lejanas más juntas
			var cy:Float = (SEL_Y + (d < 0 ? -1 : 1) * (ROW_STEP * Math.min(ad, 1) + ROW_STEP_FAR * Math.max(ad - 1, 0))) * s;
			// Curva: el icono elegido es el que más sobresale a la derecha
			var iconCX:Float = (ICON_CX - ICON_CURVE * d * d) * s;
			// Las canciones lejanas se van apagando
			var fade:Float = Math.max(0.25, Math.min(1, 1.15 - 0.3 * ad));

			var icon:HealthIcon = iconArray[i];
			var item:FlxText = songTexts[i];

			var iconSc:Float = (0.55 + 0.08 * Math.max(0, 1 - ad)) * s;
			icon.scale.set(iconSc, iconSc);
			icon.updateHitbox();
			icon.alpha = item.alpha = fade;

			// El texto va pegado a la izquierda del icono y se achica si no cabe
			var iconLeft:Float = iconCX - icon.width / 2;
			var avail:Float = iconLeft - 12 * s - 24 * s;
			var sc:Float = Math.max(0.3, Math.min(1, avail / songTextW[i]));
			item.scale.set(sc, sc);
			item.updateHitbox();

			item.visible = item.active = true;
			item.x = iconLeft - 12 * s - item.width;
			item.y = cy - item.height / 2;

			icon.visible = icon.active = true;
			icon.x = iconLeft;
			icon.y = cy - icon.height / 2;

			_lastVisibles.push(i);
		}
	}

	override function destroy():Void
	{
		super.destroy();

		FlxG.autoPause = ClientPrefs.data.autoPause;
		if (!FlxG.sound.music.playing && !stopMusicPlay)
			FlxG.sound.playMusic(Paths.music('freakyMenu'));
	}	
}

class SongMetadata
{
	public var songName:String = "";
	public var week:Int = 0;
	public var songCharacter:String = "";
	public var color:Int = -7179779;
	public var folder:String = "";
	public var lastDifficulty:String = null;
	public var composer:String = "";

	public function new(song:String, week:Int, songCharacter:String, color:Int)
	{
		this.songName = song;
		this.week = week;
		this.songCharacter = songCharacter;
		this.color = color;
		this.folder = Mods.currentModDirectory;
		if(this.folder == null) this.folder = '';
	}
}
