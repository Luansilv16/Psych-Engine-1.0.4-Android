package states;

import flixel.FlxObject;
import flixel.effects.FlxFlicker;
import lime.app.Application;
import states.editors.MasterEditorMenu;
import options.OptionsState;
import mobile.backend.MobileScaleMode;
import openfl.utils.AssetType;
import haxe.Json;

enum MainMenuColumn {
	LEFT;
	CENTER;
	RIGHT;
}

class MainMenuState extends MusicBeatState
{
	public static var psychEngineVersion:String = '1.0.4'; // This is also used for Discord RPC
	public static var curSelected:Int = 0;
	public static var curColumn:MainMenuColumn = CENTER;
	var allowMouse:Bool = true; //Turn this off to block mouse movement in menus

	var menuItems:FlxTypedGroup<FlxSprite>;
	var leftItem:FlxSprite;
	var rightItem:FlxSprite;

	// Opciones del menú: se cargan de data/mainmenu.json (editable). Si no existe, se usan las de siempre.
	var optionShit:Array<String> = [];            // columna del centro, en orden
	var actions:Map<String, String> = new Map();  // id -> acción (story_mode, freeplay, options...)
	var images:Map<String, String> = new Map();   // id -> imagen (opcional)

	var leftOption:String = null;
	var rightOption:String = null;

	var magenta:FlxSprite;
	var camFollow:FlxObject;

	static var showOutdatedWarning:Bool = true;
	override function create()
	{
		super.create();

		#if MODS_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		persistentUpdate = persistentDraw = true;

		loadMenuConfig();
		if (curSelected >= optionShit.length) curSelected = 0;
		if ((curColumn == LEFT && leftOption == null) || (curColumn == RIGHT && rightOption == null)) curColumn = CENTER;

		// Pixeles extra a cada lado cuando hay pantalla ancha (0 en 16:9)
		var cutX:Float = MobileScaleMode.gameCutoutSize.x;

		var yScroll:Float = 0.25;
		var bg:FlxSprite = new FlxSprite(-80).loadGraphic(Paths.image('menuBG'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.scrollFactor.set(0, yScroll);
		fitWide(bg, 1.175);
		add(bg);

		camFollow = new FlxObject(0, 0, 1, 1);
		add(camFollow);

		magenta = new FlxSprite(-80).loadGraphic(Paths.image('menuDesat'));
		magenta.antialiasing = ClientPrefs.data.antialiasing;
		magenta.scrollFactor.set(0, yScroll);
		fitWide(magenta, 1.175);
		magenta.visible = false;
		magenta.color = 0xFFfd719b;
		add(magenta);

		menuItems = new FlxTypedGroup<FlxSprite>();
		add(menuItems);

		var spacing:Float = Math.min(140, 560 / Math.max(1, optionShit.length));
		for (num => option in optionShit)
		{
			var item:FlxSprite = createMenuItem(option, 0, 0);
			item.y = (FlxG.height - optionShit.length * spacing) / 2 + num * spacing + 10;
			item.screenCenter(X);
			item.x += cutX;
		}

		if (leftOption != null)
			leftItem = createMenuItem(leftOption, 60, 490);
		if (rightOption != null)
		{
			rightItem = createMenuItem(rightOption, FlxG.width - 60, 490);
			rightItem.x += cutX * 2;
			rightItem.x -= rightItem.width;
		}

		var psychVer:FlxText = new FlxText(12, FlxG.height - 44, 0, "NixerEngine v" + psychEngineVersion, 12);
		psychVer.scrollFactor.set();
		psychVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(psychVer);
		var fnfVer:FlxText = new FlxText(12, FlxG.height - 24, 0, "Friday Night Funkin' v" + Application.current.meta.get('version'), 12);
		fnfVer.scrollFactor.set();
		fnfVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(fnfVer);
		changeItem();

		#if ACHIEVEMENTS_ALLOWED
		// Unlocks "Freaky on a Friday Night" achievement if it's a Friday and between 18:00 PM and 23:59 PM
		var leDate = Date.now();
		if (leDate.getDay() == 5 && leDate.getHours() >= 18)
			Achievements.unlock('friday_night_play');

		#if MODS_ALLOWED
		Achievements.reloadList();
		#end
		#end

		#if CHECK_FOR_UPDATES
		if (showOutdatedWarning && ClientPrefs.data.checkForUpdates && substates.OutdatedSubState.updateVersion != psychEngineVersion) {
			persistentUpdate = false;
			showOutdatedWarning = false;
			openSubState(new substates.OutdatedSubState());
		}
		#end

		FlxG.camera.follow(camFollow, null, 0.15);

		addTouchPad('NONE', 'E');
	}

	// Escala un fondo para que cubra toda la pantalla ancha y lo centra
	function fitWide(spr:FlxSprite, baseScale:Float):Void
	{
		var wideW:Float = FlxG.width + MobileScaleMode.gameCutoutSize.x * 2;
		var scl:Float = Math.max(baseScale, wideW / spr.width);
		spr.setGraphicSize(Std.int(spr.width * scl));
		spr.updateHitbox();
		spr.x = (wideW - spr.width) / 2;
		spr.screenCenter(Y);
	}

	// Carga data/mainmenu.json: { "items": [ {"id":"freeplay","image":"mainmenu/menu_freeplay","action":"freeplay","column":"center","visible":true}, ... ] }
	function loadMenuConfig():Void
	{
		var loaded:Bool = false;
		try
		{
			if (Paths.fileExists('data/mainmenu.json', AssetType.TEXT))
			{
				var data:Dynamic = Json.parse(Paths.getTextFromFile('data/mainmenu.json'));
				var list:Array<Dynamic> = data.items;
				for (entry in list)
				{
					if (entry.visible == false) continue;

					var id:String = Std.string(entry.id);
					var action:String = (entry.action != null) ? Std.string(entry.action) : id;
					#if !MODS_ALLOWED
					if (action == 'mods') continue;
					#end
					#if !ACHIEVEMENTS_ALLOWED
					if (action == 'achievements') continue;
					#end

					actions.set(id, action);
					if (entry.image != null) images.set(id, Std.string(entry.image));

					var column:String = (entry.column != null) ? Std.string(entry.column) : 'center';
					if (column == 'left') { if (leftOption == null) leftOption = id; }
					else if (column == 'right') { if (rightOption == null) rightOption = id; }
					else optionShit.push(id);
					loaded = true;
				}
			}
		}
		catch (e:Dynamic)
		{
			trace('mainmenu.json tiene un error: ' + e);
			loaded = false;
		}

		if (!loaded)
		{
			optionShit = ['freeplay', #if MODS_ALLOWED 'mods', #end 'credits'];
			leftOption = #if ACHIEVEMENTS_ALLOWED 'achievements' #else null #end;
			rightOption = 'options';
			actions = new Map();
			images = new Map();
		}
		if (optionShit.length == 0)
			optionShit.push('freeplay');
	}

	function createMenuItem(name:String, x:Float, y:Float):FlxSprite
	{
		var imageKey:String = images.exists(name) ? images.get(name) : 'mainmenu/menu_$name';
		var menuItem:FlxSprite = new FlxSprite(x, y);
		if (!Paths.fileExists('images/' + imageKey + '.xml', AssetType.TEXT) && Paths.fileExists('images/' + imageKey + '.png', AssetType.IMAGE))
		{
			// Imagen fija (sin animaciones)
			menuItem.loadGraphic(Paths.image(imageKey));
		}
		else
		{
			menuItem.frames = Paths.getSparrowAtlas(imageKey);
			menuItem.animation.addByPrefix('idle', '$name idle', 24, true);
			menuItem.animation.addByPrefix('selected', '$name selected', 24, true);
			menuItem.animation.play('idle');
		}
		menuItem.updateHitbox();
		
		menuItem.antialiasing = ClientPrefs.data.antialiasing;
		menuItem.scrollFactor.set();
		menuItems.add(menuItem);
		return menuItem;
	}

	// Marca/desmarca un item (con animación o, si es imagen fija, con brillo y tamaño)
	function setSelectedLook(item:FlxSprite, selected:Bool):Void
	{
		if (item.animation.exists('idle'))
		{
			item.animation.play(selected ? 'selected' : 'idle');
			item.centerOffsets();
		}
		else
		{
			item.alpha = selected ? 1 : 0.65;
			var sc:Float = selected ? 1.08 : 1;
			item.scale.set(sc, sc);
		}
	}

	var selectedSomethin:Bool = false;

	var timeNotMoving:Float = 0;
	override function update(elapsed:Float)
	{
		if (FlxG.sound.music.volume < 0.8)
			FlxG.sound.music.volume = Math.min(FlxG.sound.music.volume + 0.5 * elapsed, 0.8);

		if (!selectedSomethin)
		{
			if (controls.UI_UP_P)
				changeItem(-1);

			if (controls.UI_DOWN_P)
				changeItem(1);

			var allowMouse:Bool = allowMouse;
			if (allowMouse && ((FlxG.mouse.deltaScreenX != 0 && FlxG.mouse.deltaScreenY != 0) || FlxG.mouse.justPressed)) //FlxG.mouse.deltaScreenX/Y checks is more accurate than FlxG.mouse.justMoved
			{
				allowMouse = false;
				FlxG.mouse.visible = true;
				timeNotMoving = 0;

				var selectedItem:FlxSprite;
				switch(curColumn)
				{
					case CENTER:
						selectedItem = menuItems.members[curSelected];
					case LEFT:
						selectedItem = leftItem;
					case RIGHT:
						selectedItem = rightItem;
				}

				if(leftItem != null && FlxG.mouse.overlaps(leftItem))
				{
					allowMouse = true;
					if(selectedItem != leftItem)
					{
						curColumn = LEFT;
						changeItem();
					}
				}
				else if(rightItem != null && FlxG.mouse.overlaps(rightItem))
				{
					allowMouse = true;
					if(selectedItem != rightItem)
					{
						curColumn = RIGHT;
						changeItem();
					}
				}
				else
				{
					var dist:Float = -1;
					var distItem:Int = -1;
					for (i in 0...optionShit.length)
					{
						var memb:FlxSprite = menuItems.members[i];
						if(FlxG.mouse.overlaps(memb))
						{
							var distance:Float = Math.sqrt(Math.pow(memb.getGraphicMidpoint().x - FlxG.mouse.screenX, 2) + Math.pow(memb.getGraphicMidpoint().y - FlxG.mouse.screenY, 2));
							if (dist < 0 || distance < dist)
							{
								dist = distance;
								distItem = i;
								allowMouse = true;
							}
						}
					}

					if(distItem != -1 && selectedItem != menuItems.members[distItem])
					{
						curColumn = CENTER;
						curSelected = distItem;
						changeItem();
					}
				}
			}
			else
			{
				timeNotMoving += elapsed;
				if(timeNotMoving > 2) FlxG.mouse.visible = false;
			}

			switch(curColumn)
			{
				case CENTER:
					if(controls.UI_LEFT_P && leftOption != null)
					{
						curColumn = LEFT;
						changeItem();
					}
					else if(controls.UI_RIGHT_P && rightOption != null)
					{
						curColumn = RIGHT;
						changeItem();
					}

				case LEFT:
					if(controls.UI_RIGHT_P)
					{
						curColumn = CENTER;
						changeItem();
					}

				case RIGHT:
					if(controls.UI_LEFT_P)
					{
						curColumn = CENTER;
						changeItem();
					}
			}

			if (controls.BACK)
			{
				selectedSomethin = true;
				FlxG.mouse.visible = false;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new TitleState());
			}

			if (controls.ACCEPT || (FlxG.mouse.overlaps(menuItems, FlxG.camera) && FlxG.mouse.justPressed && allowMouse))
			{
				FlxG.sound.play(Paths.sound('confirmMenu'));
				selectedSomethin = true;
				FlxG.mouse.visible = false;

				if (ClientPrefs.data.flashing)
					FlxFlicker.flicker(magenta, 1.1, 0.15, false);

				var item:FlxSprite;
				var option:String;
				switch(curColumn)
				{
					case CENTER:
						option = optionShit[curSelected];
						item = menuItems.members[curSelected];

					case LEFT:
						option = leftOption;
						item = leftItem;

					case RIGHT:
						option = rightOption;
						item = rightItem;
				}

				FlxFlicker.flicker(item, 1, 0.06, false, false, function(flick:FlxFlicker)
				{
					switch (actions.exists(option) ? actions.get(option) : option)
					{
						case 'story_mode':
							MusicBeatState.switchState(new StoryMenuState());
						case 'freeplay':
							MusicBeatState.switchState(new FreeplayState());

						#if MODS_ALLOWED
						case 'mods':
							MusicBeatState.switchState(new ModsMenuState());
						#end

						#if ACHIEVEMENTS_ALLOWED
						case 'achievements':
							MusicBeatState.switchState(new AchievementsMenuState());
						#end

						case 'credits':
							MusicBeatState.switchState(new CreditsState());
						case 'options':
							MusicBeatState.switchState(new OptionsState());
							OptionsState.onPlayState = false;
							if (PlayState.SONG != null)
							{
								PlayState.SONG.arrowSkin = null;
								PlayState.SONG.splashSkin = null;
								PlayState.stageUI = 'normal';
							}
						case 'donate':
							CoolUtil.browserLoad('https://ninja-muffin24.itch.io/funkin');
							selectedSomethin = false;
							item.visible = true;
						default:
							trace('Menu Item ${option} doesn\'t do anything');
							selectedSomethin = false;
							item.visible = true;
					}
				});
				
				for (memb in menuItems)
				{
					if(memb == item)
						continue;

					FlxTween.tween(memb, {alpha: 0}, 0.4, {ease: FlxEase.quadOut});
				}
			}
			else if (controls.justPressed('debug_1') || touchPad.buttonE.justPressed)
			{
				selectedSomethin = true;
				FlxG.mouse.visible = false;
				MusicBeatState.switchState(new MasterEditorMenu());
			}
		}

		super.update(elapsed);
	}

	function changeItem(change:Int = 0)
	{
		if(change != 0) curColumn = CENTER;
		curSelected = FlxMath.wrap(curSelected + change, 0, optionShit.length - 1);
		FlxG.sound.play(Paths.sound('scrollMenu'));

		for (item in menuItems)
			setSelectedLook(item, false);

		var selectedItem:FlxSprite;
		switch(curColumn)
		{
			case CENTER:
				selectedItem = menuItems.members[curSelected];
			case LEFT:
				selectedItem = leftItem;
			case RIGHT:
				selectedItem = rightItem;
		}
		setSelectedLook(selectedItem, true);
		camFollow.y = selectedItem.getGraphicMidpoint().y;
	}
}
