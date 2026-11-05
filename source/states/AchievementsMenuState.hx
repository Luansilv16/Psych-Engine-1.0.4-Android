package states;

import flixel.FlxObject;
import flixel.util.FlxSort;
import flixel.math.FlxPoint;
import flixel.util.FlxSpriteUtil;
import flixel.graphics.FlxGraphic;
import openfl.utils.AssetType;
import mobile.backend.MobileScaleMode;
import objects.Bar;

#if ACHIEVEMENTS_ALLOWED
/**
 * Pantalla de logros con el diseño NixerEngine (igual que el Freeplay):
 * lista en curva a la izquierda, icono grande + descripción a la derecha.
 * Fondos: assets/shared/images/freeplay/bg.png, panel_left.png, panel_right.png
 */
class AchievementsMenuState extends MusicBeatState
{
	public var curSelected:Int = 0;

	public var options:Array<Dynamic> = [];
	public var grpOptions:FlxSpriteGroup; // iconos pequeños (uno por logro)
	public var nameText:FlxText;
	public var descText:FlxText;
	public var progressTxt:FlxText;
	public var progressBar:Bar;
	public var barTween:FlxTween = null;

	var W:Float = 1280;
	var edgeTop:Float = 400;
	var edgeBottom:Float = 240;
	var fontPath:String;
	var achTexts:Array<FlxText> = [];
	var achTextW:Array<Float> = [];
	var lerpSelected:Float = 0;
	var tint:FlxSprite;
	var bigIcon:FlxSprite;
	var lastBig:FlxGraphic = null;
	var countText:FlxText;
	var centerX:Float = 900;

	inline function pin(o:FlxObject):Void
		o.scrollFactor.set();

	override function create()
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Achievements Menu", null);
		#end

		// prepare achievement list
		for (achievement => data in Achievements.achievements)
		{
			var unlocked:Bool = Achievements.isUnlocked(achievement);
			if(data.hidden != true || unlocked)
				options.push(makeAchievement(achievement, data, unlocked, data.mod));
		}
		options.sort(sortByID);

		W = FlxG.width + MobileScaleMode.gameCutoutSize.x * 2;
		var H:Float = FlxG.height;
		var imgScale:Float = H / 1080; // los PNG de diseño miden 2164x1080
		fontPath = Paths.fileExists('fonts/freeplay.ttf', AssetType.FONT) ? Paths.font('freeplay.ttf') : Paths.font('vcr.ttf');

		// ---------- Fondo ----------
		var artBG:FlxSprite = new FlxSprite().loadGraphic(Paths.image(Paths.fileExists('images/freeplay/bg.png', AssetType.IMAGE) ? 'freeplay/bg' : 'menuBGBlue'));
		artBG.antialiasing = ClientPrefs.data.antialiasing;
		var bgScale:Float = Math.max(W / artBG.width, H / artBG.height);
		artBG.setGraphicSize(Std.int(artBG.width * bgScale));
		artBG.updateHitbox();
		artBG.setPosition((W - artBG.width) / 2, (H - artBG.height) / 2);
		pin(artBG);
		add(artBG);

		// Capa de color: dorado si el logro está desbloqueado, gris si no
		tint = new FlxSprite().makeGraphic(Std.int(W), Std.int(H), FlxColor.WHITE);
		tint.alpha = 0.3;
		tint.color = 0xFF888888;
		pin(tint);
		add(tint);

		// ---------- Icono grande (derecha) ----------
		bigIcon = new FlxSprite();
		pin(bigIcon);
		add(bigIcon);

		// ---------- Panel izquierdo ----------
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
		}
		pin(leftPanel);
		add(leftPanel);

		centerX = ((edgeTop + edgeBottom) / 2 + W) / 2;

		// ---------- Lista: texto + icono pequeño ----------
		grpOptions = new FlxSpriteGroup();
		grpOptions.scrollFactor.set();
		for (num => option in options)
		{
			var hasAntialias:Bool = ClientPrefs.data.antialiasing;
			var graphic = null;
			if(option.unlocked)
			{
				#if MODS_ALLOWED Mods.currentModDirectory = option.mod; #end
				var image:String = 'achievements/' + option.name;
				if(Paths.fileExists('images/$image-pixel.png', AssetType.IMAGE))
				{
					graphic = Paths.image('$image-pixel');
					hasAntialias = false;
				}
				else graphic = Paths.image(image);

				if(graphic == null) graphic = Paths.image('unknownMod');
			}
			else graphic = Paths.image('achievements/lockedachievement');

			var spr:FlxSprite = new FlxSprite().loadGraphic(graphic);
			var sc:Float = 56 / spr.frameHeight;
			spr.scale.set(sc, sc);
			spr.updateHitbox();
			spr.ID = num;
			spr.antialiasing = hasAntialias;
			spr.visible = false;
			grpOptions.add(spr);

			var t:FlxText = new FlxText(0, 0, 0, option.displayName, 32);
			t.setFormat(fontPath, 32, option.unlocked ? FlxColor.WHITE : 0xFFBBBBBB, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			t.borderSize = 2;
			t.antialiasing = ClientPrefs.data.antialiasing;
			t.visible = false;
			pin(t);
			achTextW.push(t.width);
			achTexts.push(t);
			add(t);
		}
		#if MODS_ALLOWED Mods.loadTopMod(); #end
		add(grpOptions);

		// ---------- Panel superior derecho: cuántos logros llevas ----------
		var rightPanel:FlxSprite;
		var panelTextX:Float;
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
			rightPanel = new FlxSprite(W - 450, 0).makeGraphic(450, 72, FlxColor.BLACK);
			panelTextX = W - 450 + 54;
		}
		pin(rightPanel);
		add(rightPanel);

		var unlockedCount:Int = 0;
		for (o in options) if (o.unlocked) unlockedCount++;
		countText = new FlxText(panelTextX, 20, 0, Language.getPhrase('achievements_unlocked', 'Achievements: {1} / {2}', [unlockedCount, options.length]), 26);
		countText.setFormat(fontPath, 26, FlxColor.WHITE, LEFT);
		pin(countText);
		add(countText);

		// ---------- Nombre, descripción y progreso (derecha) ----------
		nameText = new FlxText(centerX - 300, 400, 600, "", 34);
		nameText.setFormat(fontPath, 34, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		nameText.borderSize = 2;
		pin(nameText);

		descText = new FlxText(centerX - 290, 450, 580, "", 24);
		descText.setFormat(fontPath, 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		pin(descText);

		progressBar = new Bar(0, 600);
		progressBar.x = centerX - progressBar.width / 2;
		progressBar.scrollFactor.set();
		progressBar.enabled = false;

		progressTxt = new FlxText(centerX - 290, 594, 580, "", 28);
		progressTxt.setFormat(fontPath, 28, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		pin(progressTxt);
		progressTxt.borderSize = 2;

		add(progressBar);
		add(progressTxt);
		add(descText);
		add(nameText);

		if(options.length < 1)
		{
			nameText.text = Language.getPhrase('achievements_none', 'No achievements found');
			progressTxt.visible = progressBar.visible = false;
			addTouchPad('NONE', 'B');
			super.create();
			return;
		}

		lerpSelected = curSelected;
		_changeSelection(false);
		updateTexts(0);

		addTouchPad('UP_DOWN', 'B_C');

		super.create();
	}

	override function closeSubState() {
		super.closeSubState();
		removeTouchPad();
		addTouchPad('UP_DOWN', 'B_C');
	}

	function makeAchievement(achievement:String, data:Achievement, unlocked:Bool, mod:String = null)
	{
		return {
			name: achievement,
			displayName: unlocked ? Language.getPhrase('achievement_$achievement', data.name) : '???',
			description: Language.getPhrase('description_$achievement', data.description),
			curProgress: data.maxScore > 0 ? Achievements.getScore(achievement) : 0,
			maxProgress: data.maxScore > 0 ? data.maxScore : 0,
			decProgress: data.maxScore > 0 ? data.maxDecimals : 0,
			unlocked: unlocked,
			ID: data.ID,
			mod: mod
		};
	}

	public static function sortByID(Obj1:Dynamic, Obj2:Dynamic):Int
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1.ID, Obj2.ID);

	var goingBack:Bool = false;
	override function update(elapsed:Float) {
		if(!goingBack && options.length > 0)
		{
			var add:Int = 0;
			if (controls.UI_UP_P || controls.UI_LEFT_P) add = -1;
			else if (controls.UI_DOWN_P || controls.UI_RIGHT_P) add = 1;
			if (FlxG.mouse.wheel != 0) add = -FlxG.mouse.wheel;

			if(add != 0 && options.length > 1)
			{
				curSelected = FlxMath.wrap(curSelected + add, 0, options.length - 1);
				_changeSelection();
			}

			var canReset:Bool = (options[curSelected].unlocked || options[curSelected].curProgress > 0);
			if(canReset && (touchPad.buttonC.justPressed || controls.RESET))
			{
				removeTouchPad();
				openSubState(new ResetAchievementSubstate());
			}

			updateTexts(elapsed);

			// Si se reinició un logro, se actualiza el icono grande
			if (grpOptions.members[curSelected] != null && lastBig != grpOptions.members[curSelected].graphic)
				refreshBigIcon();
		}

		if (controls.BACK) {
			FlxG.sound.play(Paths.sound('cancelMenu'));
			MusicBeatState.switchState(new MainMenuState());
			goingBack = true;
		}
		super.update(elapsed);
	}

	// Lista en curva sobre el panel izquierdo; el texto se achica si no cabe antes del borde
	function updateTexts(elapsed:Float):Void
	{
		lerpSelected = FlxMath.lerp(curSelected, lerpSelected, Math.exp(-elapsed * 9.6));
		for (i in 0...options.length)
		{
			var d:Float = i - lerpSelected;
			var item:FlxText = achTexts[i];
			var icon:FlxSprite = grpOptions.members[i];
			item.visible = icon.visible = Math.abs(d) < 5.5;
			if (!item.visible) continue;

			var cy:Float = FlxG.height / 2 + d * 84;
			var baseX:Float = Math.max(24, 110 - 6 * d * d);
			var edge:Float = edgeTop + (edgeBottom - edgeTop) * (cy / FlxG.height);
			var avail:Float = edge - baseX - icon.width - 30;
			var sc:Float = Math.max(0.5, Math.min(1, avail / achTextW[i]));
			item.scale.set(sc, sc);
			item.updateHitbox();
			item.x = baseX;
			item.y = cy - item.height / 2;

			icon.x = item.x + item.width + 10;
			icon.y = cy - icon.height / 2;
		}
	}

	function refreshBigIcon():Void
	{
		var spr:FlxSprite = grpOptions.members[curSelected];
		lastBig = spr.graphic;
		bigIcon.loadGraphic(spr.graphic);
		bigIcon.antialiasing = spr.antialiasing;
		var sc:Float = 280 / bigIcon.frameHeight;
		bigIcon.scale.set(sc, sc);
		bigIcon.updateHitbox();
		bigIcon.setPosition(centerX - bigIcon.width / 2, 230 - bigIcon.height / 2);
		nameText.text = options[curSelected].displayName;
		tint.color = options[curSelected].unlocked ? 0xFFF9CF51 : 0xFF888888;
	}

	function _changeSelection(playSound:Bool = true)
	{
		if(playSound) FlxG.sound.play(Paths.sound('scrollMenu'));
		var hasProgress = options[curSelected].maxProgress > 0;
		nameText.text = options[curSelected].displayName;
		descText.text = options[curSelected].description;
		progressTxt.visible = progressBar.visible = hasProgress;

		if(barTween != null) barTween.cancel();

		if(hasProgress)
		{
			var val1:Float = options[curSelected].curProgress;
			var val2:Float = options[curSelected].maxProgress;
			progressTxt.text = CoolUtil.floorDecimal(val1, options[curSelected].decProgress) + ' / ' + CoolUtil.floorDecimal(val2, options[curSelected].decProgress);

			barTween = FlxTween.tween(progressBar, {percent: (val1 / val2) * 100}, 0.5, {ease: FlxEase.quadOut,
				onComplete: function(twn:FlxTween) progressBar.updateBar(),
				onUpdate: function(twn:FlxTween) progressBar.updateBar()
			});
		}
		else progressBar.percent = 0;

		for (num => item in achTexts)
		{
			item.alpha = (num == curSelected) ? 1 : 0.6;
			grpOptions.members[num].alpha = item.alpha;
		}

		refreshBigIcon();
	}
}

class ResetAchievementSubstate extends MusicBeatSubstate
{
	var onYes:Bool = false;
	var yesText:Alphabet;
	var noText:Alphabet;

	public function new()
	{
		controls.isInSubstate = true;

		super();

		var cutX:Float = mobile.backend.MobileScaleMode.gameCutoutSize.x;
		var bg:FlxSprite = new FlxSprite().makeGraphic(Std.int(FlxG.width + cutX * 2), FlxG.height, FlxColor.BLACK);
		bg.alpha = 0;
		bg.scrollFactor.set();
		add(bg);
		FlxTween.tween(bg, {alpha: 0.6}, 0.4, {ease: FlxEase.quartInOut});

		var text:Alphabet = new Alphabet(0, 180, Language.getPhrase('reset_achievement', 'Reset Achievement:'), true);
		text.screenCenter(X);
		text.x += cutX;
		text.scrollFactor.set();
		add(text);
		
		var state:AchievementsMenuState = cast FlxG.state;
		var text:FlxText = new FlxText(50 + cutX, text.y + 90, FlxG.width - 100, state.options[state.curSelected].displayName, 40);
		text.setFormat(Paths.font("vcr.ttf"), 40, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		text.scrollFactor.set();
		text.borderSize = 2;
		add(text);
		
		yesText = new Alphabet(0, text.y + 120, Language.getPhrase('Yes'), true);
		yesText.screenCenter(X);
		yesText.x += cutX - 200;
		yesText.scrollFactor.set();
		for(letter in yesText.letters) letter.color = FlxColor.RED;
		add(yesText);
		noText = new Alphabet(0, text.y + 120, Language.getPhrase('No'), true);
		noText.screenCenter(X);
		noText.x += cutX + 200;
		noText.scrollFactor.set();
		add(noText);
		updateOptions();

		addTouchPad('LEFT_RIGHT', 'A');
	}

	override function update(elapsed:Float)
	{
		if(controls.BACK)
		{
			close();
			controls.isInSubstate = false;
			FlxG.sound.play(Paths.sound('cancelMenu'));
			return;
		}

		super.update(elapsed);

		if(controls.UI_LEFT_P || controls.UI_RIGHT_P) {
			onYes = !onYes;
			updateOptions();
		}

		if(controls.ACCEPT)
		{
			if(onYes)
			{
				var state:AchievementsMenuState = cast FlxG.state;
				var option:Dynamic = state.options[state.curSelected];

				Achievements.variables.remove(option.name);
				Achievements.achievementsUnlocked.remove(option.name);
				option.unlocked = false;
				option.curProgress = 0;
				option.name = state.nameText.text = '???';
				if(option.maxProgress > 0) state.progressTxt.text = '0 / ' + option.maxProgress;
				state.grpOptions.members[state.curSelected].loadGraphic(Paths.image('achievements/lockedachievement'));
				state.grpOptions.members[state.curSelected].antialiasing = ClientPrefs.data.antialiasing;

				if(state.progressBar.visible)
				{
					if(state.barTween != null) state.barTween.cancel();
					state.barTween = FlxTween.tween(state.progressBar, {percent: 0}, 0.5, {ease: FlxEase.quadOut,
						onComplete: function(twn:FlxTween) state.progressBar.updateBar(),
						onUpdate: function(twn:FlxTween) state.progressBar.updateBar()
					});
				}
				Achievements.save();
				FlxG.save.flush();

				FlxG.sound.play(Paths.sound('cancelMenu'));
			}
			controls.isInSubstate = false;
			close();
			return;
		}
	}

	function updateOptions() {
		var scales:Array<Float> = [0.75, 1];
		var alphas:Array<Float> = [0.6, 1.25];
		var confirmInt:Int = onYes ? 1 : 0;

		yesText.alpha = alphas[confirmInt];
		yesText.scale.set(scales[confirmInt], scales[confirmInt]);
		noText.alpha = alphas[1 - confirmInt];
		noText.scale.set(scales[1 - confirmInt], scales[1 - confirmInt]);
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}
}
#end
