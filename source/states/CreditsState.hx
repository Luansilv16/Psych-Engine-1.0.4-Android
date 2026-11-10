package states;

import flixel.FlxObject;
import flixel.math.FlxPoint;
import flixel.util.FlxSpriteUtil;
import openfl.utils.AssetType;
import mobile.backend.MobileScaleMode;
import backend.MenuBG;

/**
 * Créditos futuristas NixerEngine (misma familia visual que Freeplay y Logros):
 * lista en curva a la izquierda con secciones, y a la derecha el icono de la persona
 * con anillos giratorios, tarjeta con su rol y el enlace.
 * El fondo (bg.png blanco/gris) se pinta con el color de cada persona.
 *
 * Assets (a 720 de alto): assets/shared/images/freeplay/bg.png, checker.png, panel_left.png, panel_right.png
 */
class CreditsState extends MusicBeatState
{
	var curSelected:Int = -1;
	private var creditsStuff:Array<Array<String>> = [];

	// Medidas de diseño (los PNG miden 720 de alto)
	static inline final DESIGN_H:Float = 720;
	static inline final EDGE_X:Float = 360;
	static inline final SEL_Y:Float = 360;
	static inline final ROW_H:Float = 84;      // alto de una fila de persona
	static inline final HEADER_H:Float = 64;   // alto de una cabecera de sección
	static inline final SPACER_H:Float = 28;   // alto de un espacio entre secciones
	static inline final ICON_CX:Float = 335;
	static inline final ICON_CURVE:Float = 12;
	static inline final ACCENT:Int = 0xFF00F0FF;
	static inline final ACCENT2:Int = 0xFFB000FF;

	var W:Float = 1280;
	var fontPath:String;
	var centerX:Float = 900;

	var bg:FlxSprite;
	var bgTween:FlxTween = null;
	var intendedColor:FlxColor;
	var leftPanel:FlxSprite;
	var rightPanel:FlxSprite;
	var selBar:FlxSprite;
	var chevron:FlxSprite;
	var ringA:FlxSprite;
	var ringB:FlxSprite;
	var beam:FlxSprite;
	var bigIcon:FlxSprite;
	var bigBase:Float = 1;
	var nameText:FlxText;
	var descText:FlxText;
	var linkText:FlxText;
	var sectionText:FlxText;
	var cardBox:FlxSprite;
	var cardLine:FlxSprite;

	// Filas (mismo índice que creditsStuff)
	var rowTexts:Array<FlxText> = [];
	var rowTextW:Array<Float> = [];
	var rowIcons:Array<FlxSprite> = [];
	var rowKind:Array<Int> = [];      // 0 = persona, 1 = cabecera, 2 = espacio
	var rowY:Array<Float> = [];       // centro de cada fila en el mapa de la lista
	var sectionOf:Array<String> = [];
	var scrollY:Float = 0;

	var introProg:Float = 0;
	var animT:Float = 0;
	var descFull:String = '';
	var descShown:Float = 0;

	inline function pin(o:FlxObject):Void
		o.scrollFactor.set();

	override function create()
	{
		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		persistentUpdate = true;

		W = FlxG.width + MobileScaleMode.gameCutoutSize.x * 2;
		var H:Float = FlxG.height;
		var imgScale:Float = H / DESIGN_H;
		var aa:Bool = ClientPrefs.data.antialiasing;
		centerX = (EDGE_X * imgScale + W) / 2;

		fontPath = Paths.font('vcr.ttf');
		if (Paths.fileExists('fonts/freeplay.otf', AssetType.FONT)) fontPath = Paths.font('freeplay.otf');
		else if (Paths.fileExists('fonts/freeplay.ttf', AssetType.FONT)) fontPath = Paths.font('freeplay.ttf');

		#if MODS_ALLOWED
		pushModCreditsToList('');
		for (mod in Mods.parseList().enabled) pushModCreditsToList(mod);
		#end

		var defaultList:Array<Array<String>> = [ //Name - Icon name - Description - Link - BG Color
			['NixerEngine Dev'],
			["Nyxen Roaring", "nyx", "Who built the port? A fucking Chilean piece of shit.", "https://youtube.com/@nyxen-roaring-original", "2B2B47"],
			["Toji", "toji", "The Engine Tester, thank you, sweetheart.", "https://x.com/Ahllo_sb8pz", "393939"],
			[''],
			['Mobile Porting Team'],
			['HomuHomu833',			'homura',             'Head Porter of Psych Engine and Author of linc_luajit-rewriten',                       'https://youtube.com/@HomuHomu833',		'FFE7C0'],
			['Karim Akra',			'karim',			'Second Porter of Psych Engine',						'https://youtube.com/@Karim0690',		'FFB4F0'],
			['Moxie',				'moxie',			'Helper of Psych Engine Mobile',							'https://twitter.com/moxie_specalist',  'F592C4'],
			[''],
			["Psych Engine Team"],
			["Shadow Mario",		"shadowmario",		"Main Programmer and Head of Psych Engine",					"https://ko-fi.com/shadowmario",	"444444"],
			["Riveren",				"riveren",			"Main Artist/Animator of Psych Engine",						"https://x.com/riverennn",			"14967B"],
			[""],
			["Funkin' Crew"],
			["ninjamuffin99",		"ninjamuffin99",	"Programmer of Friday Night Funkin'",						"https://x.com/ninja_muffin99",		"CF2D2D"],
			["PhantomArcade",		"phantomarcade",	"Animator of Friday Night Funkin'",							"https://x.com/PhantomArcade3K",	"FADC45"],
			["evilsk8r",			"evilsk8r",			"Artist of Friday Night Funkin'",							"https://x.com/evilsk8r",			"5ABD4B"],
			["kawaisprite",			"kawaisprite",		"Composer of Friday Night Funkin'",							"https://x.com/kawaisprite",		"378FC7"]
		];

		for(i in defaultList)
			creditsStuff.push(i);

		// ---------- Fondo (blanco/gris: se pinta directo con el color de cada persona) ----------
		bg = MenuBG.create('menuDesat');
		add(bg);

		if (Paths.fileExists('images/freeplay/checker.png', AssetType.IMAGE))
		{
			var checker:FlxSprite = new FlxSprite().loadGraphic(Paths.image('freeplay/checker'));
			checker.antialiasing = aa;
			var cs:Float = Math.max(W / checker.width, H / checker.height);
			checker.setGraphicSize(Std.int(checker.width * cs));
			checker.updateHitbox();
			checker.setPosition((W - checker.width) / 2, (H - checker.height) / 2);
			pin(checker);
			add(checker);
		}

		// ---------- Anillos HUD detrás del icono grande ----------
		var ringSize:Int = 270;
		ringA = new FlxSprite().makeGraphic(ringSize, ringSize, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawRect(ringA, 3, 3, ringSize - 6, ringSize - 6, FlxColor.TRANSPARENT, {thickness: 3, color: ACCENT});
		ringA.antialiasing = true;
		ringA.setPosition(centerX - ringSize / 2, 190 - ringSize / 2);
		ringA.alpha = 0;
		pin(ringA);
		add(ringA);

		var ringSizeB:Int = 230;
		ringB = new FlxSprite().makeGraphic(ringSizeB, ringSizeB, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawRect(ringB, 3, 3, ringSizeB - 6, ringSizeB - 6, FlxColor.TRANSPARENT, {thickness: 2, color: ACCENT2});
		ringB.antialiasing = true;
		ringB.setPosition(centerX - ringSizeB / 2, 190 - ringSizeB / 2);
		ringB.angle = 45;
		ringB.alpha = 0;
		pin(ringB);
		add(ringB);

		beam = new FlxSprite(EDGE_X * imgScale, -4).makeGraphic(Std.int(W - EDGE_X * imgScale), 2, ACCENT);
		beam.alpha = 0.18;
		pin(beam);
		add(beam);

		bigIcon = new FlxSprite();
		pin(bigIcon);
		add(bigIcon);

		// ---------- Tarjeta de descripción (derecha) ----------
		cardBox = new FlxSprite(centerX - 300, 395).makeGraphic(600, 10, FlxColor.BLACK);
		cardBox.alpha = 0.55;
		pin(cardBox);
		add(cardBox);

		cardLine = new FlxSprite(centerX - 300, 393).makeGraphic(600, 2, ACCENT);
		pin(cardLine);
		add(cardLine);

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

		selBar = new FlxSprite(0, SEL_Y * imgScale - 30).makeGraphic(Std.int(EDGE_X * imgScale + 30), 60, ACCENT);
		selBar.alpha = 0.15;
		pin(selBar);
		add(selBar);

		chevron = new FlxSprite().makeGraphic(14, 26, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawPolygon(chevron, [FlxPoint.get(0, 0), FlxPoint.get(14, 13), FlxPoint.get(0, 26)], ACCENT);
		chevron.setPosition(10, SEL_Y * imgScale - 13);
		pin(chevron);
		add(chevron);

		// ---------- Filas: personas, cabeceras de sección y espacios ----------
		var acc:Float = 0;
		var section:String = '';
		for (i => credit in creditsStuff)
		{
			var isSelectable:Bool = !unselectableCheck(i);
			var isHeader:Bool = !isSelectable && credit[0] != null && credit[0].trim().length > 0;
			if (isHeader) section = credit[0];
			sectionOf.push(section);

			var h:Float = isSelectable ? ROW_H : (isHeader ? HEADER_H : SPACER_H);
			rowY.push(acc + h / 2);
			acc += h;
			rowKind.push(isSelectable ? 0 : (isHeader ? 1 : 2));

			var label:String = isHeader ? credit[0].toUpperCase() : (isSelectable ? credit[0] : ' ');
			var t:FlxText = new FlxText(0, 0, 0, label, isHeader ? 22 : 32);
			if (isHeader) t.setFormat(fontPath, 22, ACCENT, LEFT);
			else
			{
				t.setFormat(fontPath, 32, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				t.borderSize = 2;
			}
			t.antialiasing = aa;
			t.visible = false;
			pin(t);
			rowTextW.push(t.width);
			rowTexts.push(t);
			add(t);

			if (isSelectable)
			{
				if (credit[5] != null)
					Mods.currentModDirectory = credit[5];

				var str:String = 'credits/missing_icon';
				if (credit[1] != null && credit[1].length > 0)
				{
					var fileName = 'credits/' + credit[1];
					if (Paths.fileExists('images/$fileName.png', IMAGE)) str = fileName;
					else if (Paths.fileExists('images/$fileName-pixel.png', IMAGE)) str = fileName + '-pixel';
				}

				var icon:FlxSprite = new FlxSprite().loadGraphic(Paths.image(str));
				var sc:Float = 60 / icon.frameHeight;
				icon.scale.set(sc, sc);
				icon.updateHitbox();
				icon.antialiasing = str.endsWith('-pixel') ? false : aa;
				icon.visible = false;
				pin(icon);
				rowIcons.push(icon);
				add(icon);
				Mods.currentModDirectory = '';

				if (curSelected == -1) curSelected = i;
			}
			else rowIcons.push(null);
		}
		if (curSelected == -1) curSelected = 0;
		scrollY = rowY[curSelected];

		// ---------- Cabecera superior derecha: nombre de la sección ----------
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

		var secY:Float = 24;
		sectionText = new FlxText(panelTextX, secY - rightPanel.height, 0, '', 26);
		sectionText.setFormat(fontPath, 26, FlxColor.WHITE, LEFT);
		pin(sectionText);
		add(sectionText);

		var hdrY:Float = rightPanel.y;
		rightPanel.y = hdrY - rightPanel.height;
		FlxTween.tween(rightPanel, {y: hdrY}, 0.45, {startDelay: 0.15, ease: FlxEase.quartOut});
		FlxTween.tween(sectionText, {y: secY}, 0.45, {startDelay: 0.15, ease: FlxEase.quartOut});

		// ---------- Textos de la derecha ----------
		nameText = new FlxText(centerX - 310, 330, 620, '', 40);
		nameText.setFormat(fontPath, 40, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		nameText.borderSize = 2;
		pin(nameText);
		add(nameText);

		descText = new FlxText(centerX - 285, 405, 570, '', 24);
		descText.setFormat(fontPath, 24, FlxColor.WHITE, CENTER);
		pin(descText);
		add(descText);

		linkText = new FlxText(centerX - 300, 650, 600, '', 20);
		linkText.setFormat(fontPath, 20, ACCENT, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		linkText.borderSize = 1.5;
		pin(linkText);
		add(linkText);

		bg.color = colorOf(curSelected);
		intendedColor = bg.color;
		changeSelection();

		var bgWarning:FlxText = MenuBG.warning();
		if (bgWarning != null) add(bgWarning);

		addTouchPad('UP_DOWN', 'A_B');

		super.create();
	}

	function colorOf(i:Int):FlxColor
	{
		var c:String = creditsStuff[i][4];
		if (c == null || c.length < 1) return 0xFF6A6AA0;
		// Los colores muy oscuros (2B2B47, 393939...) se aclaran para que el fondo no quede negro
		return MenuBG.lift(CoolUtil.colorFromString(c));
	}

	// Muestra solo el dominio/usuario del enlace
	function shortLink(url:String):String
	{
		var s:String = url;
		if (s.startsWith('https://')) s = s.substr(8);
		else if (s.startsWith('http://')) s = s.substr(7);
		if (s.startsWith('www.')) s = s.substr(4);
		return s;
	}

	var quitting:Bool = false;
	var holdTime:Float = 0;
	override function update(elapsed:Float)
	{
		if (FlxG.sound.music.volume < 0.7)
		{
			FlxG.sound.music.volume += 0.5 * elapsed;
		}

		if(!quitting)
		{
			if(creditsStuff.length > 1)
			{
				var shiftMult:Int = 1;
				if(FlxG.keys.pressed.SHIFT) shiftMult = 3;

				var upP = controls.UI_UP_P;
				var downP = controls.UI_DOWN_P;

				if (upP)
				{
					changeSelection(-shiftMult);
					holdTime = 0;
				}
				if (downP)
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
					{
						changeSelection((checkNewHold - checkLastHold) * (controls.UI_UP ? -shiftMult : shiftMult));
					}
				}

				if (FlxG.mouse.wheel != 0)
					changeSelection(-FlxG.mouse.wheel);
			}

			var link:String = creditsStuff[curSelected][3];
			if(controls.ACCEPT && link != null && link.length > 4)
			{
				#if ACHIEVEMENTS_ALLOWED
				if(creditsStuff[curSelected][0] == "Nyxen Roaring")
					Achievements.unlock('subscribe_nyx');
				#end
				CoolUtil.browserLoad(link);
			}
			if (controls.BACK)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new MainMenuState());
				quitting = true;
			}
		}

		updateRows(elapsed);

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
		cardLine.alpha = 0.6 + 0.4 * Math.sin(animT * 3);

		// Descripción que se escribe sola
		if (descShown < descFull.length)
		{
			descShown += elapsed * 90;
			descText.text = descFull.substr(0, Std.int(Math.min(descShown, descFull.length)));
		}

		super.update(elapsed);
	}

	// Lista en curva: la fila elegida queda fija en SEL_Y y el resto se desplaza según el mapa rowY
	function updateRows(elapsed:Float):Void
	{
		scrollY = FlxMath.lerp(rowY[curSelected], scrollY, Math.exp(-elapsed * 9.6));
		introProg = Math.min(1, introProg + elapsed / 1.0);

		var s:Float = FlxG.height / DESIGN_H;
		for (i in 0...creditsStuff.length)
		{
			var item:FlxText = rowTexts[i];
			var icon:FlxSprite = rowIcons[i];
			var dy:Float = rowY[i] - scrollY;
			var vis:Bool = Math.abs(dy) < 430 && rowKind[i] != 2;
			item.visible = vis;
			if (icon != null) icon.visible = vis;
			if (!vis) continue;

			var ad:Float = Math.abs(dy) / ROW_H;
			var cy:Float = (SEL_Y + dy) * s;
			var iconCX:Float = (ICON_CX - ICON_CURVE * ad * ad) * s;
			var fade:Float = Math.max(0.2, Math.min(1, 1.15 - 0.28 * ad));

			var ie:Float = FlxEase.quartOut(FlxMath.bound(introProg * 1.8 - ad * 0.15, 0, 1));
			var slide:Float = -(1 - ie) * 260 * s;

			if (rowKind[i] == 0)
			{
				var iconLeft:Float = iconCX - icon.width / 2;
				var avail:Float = iconLeft - 12 * s - 24 * s;
				var sc:Float = Math.max(0.4, Math.min(1, avail / rowTextW[i]));
				item.scale.set(sc, sc);
				item.updateHitbox();

				item.x = iconLeft - 12 * s - item.width + slide;
				item.y = cy - item.height / 2;
				icon.x = iconLeft + slide;
				icon.y = cy - icon.height / 2;
				item.alpha = icon.alpha = fade * ie;
			}
			else
			{
				// Cabecera de sección: pegada al borde del panel, en cian
				item.x = iconCX + 20 * s - item.width + slide;
				item.y = cy - item.height / 2;
				item.alpha = Math.min(1, fade + 0.15) * ie;
			}
		}
	}

	function changeSelection(change:Int = 0)
	{
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		do
		{
			curSelected = FlxMath.wrap(curSelected + change, 0, creditsStuff.length - 1);
		}
		while(unselectableCheck(curSelected));

		var credit:Array<String> = creditsStuff[curSelected];

		// Fondo: se pinta directo con el color de la persona
		var newColor:FlxColor = colorOf(curSelected);
		if(newColor != intendedColor)
		{
			intendedColor = newColor;
			if (bgTween != null) bgTween.cancel();
			bgTween = FlxTween.color(bg, 0.8, bg.color, intendedColor);
		}

		// Icono grande: "salta" al cambiar (escala desde su centro)
		var spr:FlxSprite = rowIcons[curSelected];
		if (spr != null)
		{
			bigIcon.loadGraphic(spr.graphic);
			bigIcon.antialiasing = spr.antialiasing;
			bigBase = 200 / bigIcon.frameHeight;
			bigIcon.setPosition(centerX - bigIcon.frameWidth / 2, 190 - bigIcon.frameHeight / 2);
			FlxTween.cancelTweensOf(bigIcon.scale);
			bigIcon.scale.set(bigBase * 0.6, bigBase * 0.6);
			FlxTween.tween(bigIcon.scale, {x: bigBase, y: bigBase}, 0.35, {ease: FlxEase.backOut});
		}

		sectionText.text = sectionOf[curSelected].toUpperCase();

		nameText.text = credit[0];
		FlxTween.cancelTweensOf(nameText);
		nameText.alpha = 0;
		nameText.y = 342;
		FlxTween.tween(nameText, {alpha: 1, y: 330}, 0.25, {ease: FlxEase.quartOut});

		// Descripción que se escribe sola (ver update)
		descFull = (credit[2] != null) ? credit[2] : '';
		descShown = 0;
		descText.text = '';

		var hasDesc:Bool = descFull.trim().length > 0;
		descText.visible = cardBox.visible = cardLine.visible = hasDesc;
		if (hasDesc)
		{
			// Mide el texto completo para ajustar la tarjeta, luego lo deja vacío para escribirlo
			descText.text = descFull;
			cardBox.setGraphicSize(600, Std.int(descText.height + 24));
			cardBox.updateHitbox();
			cardBox.setPosition(centerX - 300, 395);
			descText.y = 407;
			descText.text = '';
		}

		var link:String = credit[3];
		if (link != null && link.length > 4)
		{
			var key:String = controls.mobileC ? 'A' : 'ENTER';
			linkText.text = '[' + key + ']  ' + shortLink(link);
			linkText.visible = true;
		}
		else linkText.visible = false;
	}

	#if MODS_ALLOWED
	function pushModCreditsToList(folder:String)
	{
		var creditsFile:String = Paths.mods((folder.length > 0 ? folder + '/' : '') + 'data/credits.txt');

		#if TRANSLATIONS_ALLOWED
		//trace('/data/credits-${ClientPrefs.data.language}.txt');
		var translatedCredits:String = Paths.mods((folder.length > 0 ? folder + '/' : '') + 'data/credits-${ClientPrefs.data.language}.txt');
		#end

		if (#if TRANSLATIONS_ALLOWED (FileSystem.exists(translatedCredits) && (creditsFile = translatedCredits) == translatedCredits) || #end FileSystem.exists(creditsFile))
		{
			var firstarray:Array<String> = File.getContent(creditsFile).split('\n');
			for(i in firstarray)
			{
				var arr:Array<String> = i.replace('\\n', '\n').split("::");
				if(arr.length >= 5) arr.push(folder);
				creditsStuff.push(arr);
			}
			creditsStuff.push(['']);
		}
	}
	#end

	private function unselectableCheck(num:Int):Bool {
		return creditsStuff[num].length <= 1;
	}
}
