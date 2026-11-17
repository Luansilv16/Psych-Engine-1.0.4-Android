package states;

import flixel.FlxObject;
import flixel.util.FlxSort;
import flixel.math.FlxPoint;
import flixel.util.FlxSpriteUtil;
import flixel.graphics.FlxGraphic;
import openfl.utils.AssetType;
import mobile.backend.MobileScaleMode;
import objects.Bar;
import backend.MenuBG;

#if ACHIEVEMENTS_ALLOWED
/**
 * Pantalla de logros futurista NixerEngine (misma familia visual que el Freeplay):
 * lista en curva a la izquierda, icono grande con anillos giratorios a la derecha.
 *
 * Animaciones: paneles que se deslizan al entrar, lista que entra escalonada,
 * barra de selección que pulsa, anillos HUD que giran, rayo de escaneo,
 * icono que "salta" al cambiar, nombre que aparece y descripción que se escribe sola.
 *
 * Assets (a 720 de alto): assets/shared/images/freeplay/bg.png, panel_left.png, panel_right.png
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

	// Medidas de diseño (los PNG miden 720 de alto)
	static inline final DESIGN_H:Float = 720;
	static inline final EDGE_X:Float = 360;      // x del borde azul del panel izquierdo
	static inline final SEL_Y:Float = 360;       // y del centro de la fila elegida
	static inline final ROW_STEP:Float = 92;     // separación entre filas
	static inline final ICON_CX:Float = 335;     // x del centro del icono de la fila elegida
	static inline final ICON_CURVE:Float = 12;   // cuánto se curva la lista
	static inline final ACCENT:Int = 0xFF00F0FF;
	static inline final ACCENT2:Int = 0xFFB000FF;

	var W:Float = 1280;
	var fontPath:String;
	var achTexts:Array<FlxText> = [];
	var achTextW:Array<Float> = [];
	var lerpSelected:Float = 0;
	var bigIcon:FlxSprite;
	var bigBase:Float = 1;
	var lastBig:FlxGraphic = null;
	var countText:FlxText;
	var centerX:Float = 900;

	var artBG:FlxSprite;
	var bgTween:FlxTween = null;
	var bgFirst:Bool = true;
	var leftPanel:FlxSprite;
	var rightPanel:FlxSprite;
	var selBar:FlxSprite;
	var chevron:FlxSprite;
	var ringA:FlxSprite;
	var ringB:FlxSprite;
	var beam:FlxSprite;

	var introProg:Float = 0;
	var animT:Float = 0;
	var descFull:String = '';
	var descShown:Float = 0;

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
		var imgScale:Float = H / DESIGN_H;
		var aa:Bool = ClientPrefs.data.antialiasing;

		fontPath = Paths.font('vcr.ttf');
		if (Paths.fileExists('fonts/freeplay.otf', AssetType.FONT)) fontPath = Paths.font('freeplay.otf');
		else if (Paths.fileExists('fonts/freeplay.ttf', AssetType.FONT)) fontPath = Paths.font('freeplay.ttf');

		centerX = (EDGE_X * imgScale + W) / 2;

		// ---------- Fondo (blanco/gris, se pinta directo: dorado = desbloqueado, gris = bloqueado) ----------
		artBG = MenuBG.create('menuBGBlue');
		add(artBG);

		// ---------- Anillos HUD giratorios detrás del icono grande ----------
		var ringSize:Int = 330;
		ringA = new FlxSprite().makeGraphic(ringSize, ringSize, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawRect(ringA, 3, 3, ringSize - 6, ringSize - 6, FlxColor.TRANSPARENT, {thickness: 3, color: ACCENT});
		ringA.antialiasing = true;
		ringA.setPosition(centerX - ringSize / 2, 230 - ringSize / 2);
		ringA.alpha = 0;
		pin(ringA);
		add(ringA);

		var ringSizeB:Int = 280;
		ringB = new FlxSprite().makeGraphic(ringSizeB, ringSizeB, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawRect(ringB, 3, 3, ringSizeB - 6, ringSizeB - 6, FlxColor.TRANSPARENT, {thickness: 2, color: ACCENT2});
		ringB.antialiasing = true;
		ringB.setPosition(centerX - ringSizeB / 2, 230 - ringSizeB / 2);
		ringB.angle = 45;
		ringB.alpha = 0;
		pin(ringB);
		add(ringB);

		// ---------- Rayo de escaneo que baja por la zona derecha ----------
		beam = new FlxSprite(EDGE_X * imgScale, -4).makeGraphic(Std.int(W - EDGE_X * imgScale), 2, ACCENT);
		beam.alpha = 0.18;
		pin(beam);
		add(beam);

		// ---------- Icono grande (derecha) ----------
		bigIcon = new FlxSprite();
		pin(bigIcon);
		add(bigIcon);

		// ---------- Panel izquierdo (entra deslizándose) ----------
		if (Paths.fileExists('images/freeplay/panel_left.png', AssetType.IMAGE))
		{
			leftPanel = new FlxSprite().loadGraphic(Paths.image('freeplay/panel_left'));
			leftPanel.antialiasing = aa;
			leftPanel.scale.set(imgScale, imgScale);
			leftPanel.updateHitbox();
		}
		else
		{
			leftPanel = new FlxSprite().makeGraphic(Std.int(EDGE_X * imgScale), Std.int(H), FlxColor.BLACK);
		}
		leftPanel.setPosition(-leftPanel.width, 0);
		FlxTween.tween(leftPanel, {x: 0}, 0.5, {ease: FlxEase.quartOut});
		pin(leftPanel);
		add(leftPanel);

		// ---------- Barra de selección + flecha (pulsan en update) ----------
		selBar = new FlxSprite(0, SEL_Y * imgScale - 30).makeGraphic(Std.int(EDGE_X * imgScale + 30), 60, ACCENT);
		selBar.alpha = 0.15;
		pin(selBar);
		add(selBar);

		chevron = new FlxSprite().makeGraphic(14, 26, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawPolygon(chevron, [FlxPoint.get(0, 0), FlxPoint.get(14, 13), FlxPoint.get(0, 26)], ACCENT);
		chevron.setPosition(10, SEL_Y * imgScale - 13);
		pin(chevron);
		add(chevron);

		// ---------- Lista: texto + icono pequeño ----------
		grpOptions = new FlxSpriteGroup();
		grpOptions.scrollFactor.set();
		for (num => option in options)
		{
			var hasAntialias:Bool = aa;
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
			t.antialiasing = aa;
			t.visible = false;
			pin(t);
			achTextW.push(t.width);
			achTexts.push(t);
			add(t);
		}
		#if MODS_ALLOWED Mods.loadTopMod(); #end
		add(grpOptions);

		// ---------- Cabecera superior derecha (entra desde arriba) ----------
		var panelTextX:Float;
		if (Paths.fileExists('images/freeplay/panel_right.png', AssetType.IMAGE))
		{
			rightPanel = new FlxSprite().loadGraphic(Paths.image('freeplay/panel_right'));
			rightPanel.antialiasing = aa;
			rightPanel.scale.set(imgScale, imgScale);
			rightPanel.updateHitbox();
			rightPanel.setPosition(W - rightPanel.width, 0);
			panelTextX = rightPanel.x + 49 * imgScale;
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
		var countY:Float = 24;
		countText = new FlxText(panelTextX, countY - rightPanel.height, 0, Language.getPhrase('achievements_unlocked', 'Achievements: {1} / {2}', [unlockedCount, options.length]), 26);
		countText.setFormat(fontPath, 26, FlxColor.WHITE, LEFT);
		pin(countText);
		add(countText);

		var hdrY:Float = rightPanel.y;
		rightPanel.y = hdrY - rightPanel.height;
		FlxTween.tween(rightPanel, {y: hdrY}, 0.45, {startDelay: 0.15, ease: FlxEase.quartOut});
		FlxTween.tween(countText, {y: countY}, 0.45, {startDelay: 0.15, ease: FlxEase.quartOut});

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

		var bgWarning:FlxText = MenuBG.warning();
		if (bgWarning != null) add(bgWarning);

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

		// ---------- Animaciones ambientales ----------
		animT += elapsed;
		ringA.angle += elapsed * 22;
		ringB.angle -= elapsed * 38;
		var rv:Float = FlxMath.bound((introProg - 0.35) / 0.65, 0, 1);
		ringA.alpha = 0.55 * rv;
		ringB.alpha = 0.4 * rv;
		beam.y += elapsed * 150;
		if (beam.y > FlxG.height) beam.y = -4;
		selBar.alpha = (0.13 + 0.06 * Math.sin(animT * 4)) * rv;
		chevron.x = 10 + 4 * Math.sin(animT * 6);
		chevron.alpha = rv;

		// Descripción que se escribe sola
		if (descShown < descFull.length)
		{
			descShown += elapsed * 90;
			descText.text = descFull.substr(0, Std.int(Math.min(descShown, descFull.length)));
		}

		if (controls.BACK) {
			FlxG.sound.play(Paths.sound('cancelMenu'));
			MusicBeatState.switchState(new MainMenuState());
			goingBack = true;
		}
		super.update(elapsed);
	}

	// Lista en curva sobre el panel izquierdo: texto pegado a la izquierda del icono, que
	// queda sobre el borde azul. Las filas lejanas se apagan; al entrar llegan escalonadas.
	function updateTexts(elapsed:Float):Void
	{
		lerpSelected = FlxMath.lerp(curSelected, lerpSelected, Math.exp(-elapsed * 9.6));
		introProg = Math.min(1, introProg + elapsed / 1.0);

		var s:Float = FlxG.height / DESIGN_H;
		for (i in 0...options.length)
		{
			var d:Float = i - lerpSelected;
			var ad:Float = Math.abs(d);
			var item:FlxText = achTexts[i];
			var icon:FlxSprite = grpOptions.members[i];
			item.visible = icon.visible = ad < 5.5;
			if (!item.visible) continue;

			var cy:Float = (SEL_Y + d * ROW_STEP) * s;
			var iconCX:Float = (ICON_CX - ICON_CURVE * d * d) * s;
			var fade:Float = Math.max(0.2, Math.min(1, 1.15 - 0.28 * ad));

			// Entrada: cada fila llega desde la izquierda con retraso según su distancia
			var ie:Float = FlxEase.quartOut(FlxMath.bound(introProg * 1.8 - ad * 0.15, 0, 1));
			var slide:Float = -(1 - ie) * 260 * s;

			var iconLeft:Float = iconCX - icon.width / 2;
			var avail:Float = iconLeft - 12 * s - 24 * s;
			var sc:Float = Math.max(0.4, Math.min(1, avail / achTextW[i]));
			item.scale.set(sc, sc);
			item.updateHitbox();

			item.x = iconLeft - 12 * s - item.width + slide;
			item.y = cy - item.height / 2;
			icon.x = iconLeft + slide;
			icon.y = cy - icon.height / 2;
			item.alpha = icon.alpha = fade * ie;
		}
	}

	function refreshBigIcon():Void
	{
		var spr:FlxSprite = grpOptions.members[curSelected];
		lastBig = spr.graphic;
		bigIcon.loadGraphic(spr.graphic);
		bigIcon.antialiasing = spr.antialiasing;

		// El icono escala desde su centro (sin updateHitbox) y "salta" al cambiar
		bigBase = 280 / bigIcon.frameHeight;
		bigIcon.setPosition(centerX - bigIcon.frameWidth / 2, 230 - bigIcon.frameHeight / 2);
		FlxTween.cancelTweensOf(bigIcon.scale);
		bigIcon.scale.set(bigBase * 0.6, bigBase * 0.6);
		FlxTween.tween(bigIcon.scale, {x: bigBase, y: bigBase}, 0.35, {ease: FlxEase.backOut});

		nameText.text = options[curSelected].displayName;

		// Fondo: dorado si está desbloqueado, gris si no
		var target:Int = options[curSelected].unlocked ? 0xFFF9CF51 : 0xFF888888;
		if (bgTween != null) bgTween.cancel();
		if (bgFirst)
		{
			artBG.color = target;
			bgFirst = false;
		}
		else bgTween = FlxTween.color(artBG, 0.4, artBG.color, target);
	}

	function _changeSelection(playSound:Bool = true)
	{
		if(playSound) FlxG.sound.play(Paths.sound('scrollMenu'));
		var hasProgress = options[curSelected].maxProgress > 0;
		nameText.text = options[curSelected].displayName;

		// Nombre que sube un poco mientras aparece
		FlxTween.cancelTweensOf(nameText);
		nameText.alpha = 0;
		nameText.y = 412;
		FlxTween.tween(nameText, {alpha: 1, y: 400}, 0.25, {ease: FlxEase.quartOut});

		// Descripción que se escribe sola (ver update)
		descFull = options[curSelected].description;
		descShown = 0;
		descText.text = '';

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
