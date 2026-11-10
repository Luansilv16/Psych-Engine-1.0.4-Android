package states.editors;

import backend.WeekData;
import backend.MenuBG;

import objects.Character;

import states.MainMenuState;
import states.FreeplayState;

import flixel.FlxObject;
import flixel.math.FlxPoint;
import flixel.util.FlxSpriteUtil;
import flixel.util.FlxTimer;
import openfl.utils.AssetType;
import mobile.backend.MobileScaleMode;

/**
 * Menú de editores futurista NixerEngine (misma familia visual que Freeplay, Logros y Créditos).
 *
 * - Izquierda: lista de editores en curva sobre el panel.
 * - Centro: número, nombre y descripción del editor elegido, con anillos giratorios.
 * - Derecha: lista larga de mods (con scroll). Sin la barra negra de abajo.
 *
 * Controles (todo funciona con los botones en pantalla de Android):
 *   ARRIBA / ABAJO ... mover en la lista activa (mantener pulsado repite)
 *   DERECHA ......... pasar a la lista de MODS      IZQUIERDA ... volver a EDITORES
 *   A ............... abrir el editor (o confirmar el mod)
 *   B ............... volver (desde MODS vuelve a EDITORES; desde EDITORES sale al menú)
 * El mod elegido se aplica al instante, igual que antes con los < >.
 *
 * Assets (a 720 de alto): assets/shared/images/freeplay/bg.png, checker.png, panel_left.png, panel_right.png
 */
class MasterEditorMenu extends MusicBeatState
{
	var options:Array<String> = [
		'Chart Editor',
		'Character Editor',
		'Stage Editor',
		'Week Editor',
		'Menu Character Editor',
		'Dialogue Editor',
		'Dialogue Portrait Editor',
		'Note Splash Editor',
		'Menu Editor',
		'Credits Editor'
	];

	// Misma longitud y orden que `options`
	var descriptions:Array<String> = [
		'Create and edit song charts',
		'Edit characters, animations and offsets',
		'Build and edit stages',
		'Create and edit story mode weeks',
		'Edit the characters of the story menu',
		'Write and edit in-game dialogue',
		'Edit dialogue character portraits',
		'Tune note splash animations',
		'Edit menu items and layout',
		'Edit the credits list'
	];

	// Color con el que se pinta el fondo para cada editor
	var colors:Array<Int> = [
		0xFF4D7CFF, 0xFFB04DFF, 0xFF28C7A0, 0xFFFFA24D, 0xFFFF5D8F,
		0xFF4DD2FF, 0xFF8F7CFF, 0xFFFFD24D, 0xFF58E06F, 0xFFFF6B4D
	];

	private var directories:Array<String> = [null];
	private var curSelected:Int = 0;
	private var curDirectory:Int = 0;

	// Medidas de diseño (los PNG miden 720 de alto)
	static inline final DESIGN_H:Float = 720;
	static inline final EDGE_X:Float = 360;      // x del borde azul del panel izquierdo
	static inline final SEL_Y:Float = 360;       // y del centro de la fila elegida
	static inline final ROW_STEP:Float = 92;     // separación entre filas
	static inline final NODE_CX:Float = 335;     // x del rombo de la fila elegida
	static inline final ROW_CURVE:Float = 12;    // cuánto se curva la lista
	static inline final CARD_W:Float = 330;      // ancho de la tarjeta de mods
	static inline final CARD_Y:Float = 92;       // y de la tarjeta de mods
	static inline final MOD_ROW:Float = 52;      // alto de cada fila de mod
	static inline final LIST_TOP:Float = 156;    // y donde empieza la lista de mods
	static inline final LIST_BOTTOM:Float = 692; // y donde termina la lista de mods
	static inline final ACCENT:Int = 0xFF00F0FF;
	static inline final ACCENT2:Int = 0xFFB000FF;

	var W:Float = 1280;
	var fontPath:String;
	var centerX:Float = 700;

	var bg:FlxSprite;
	var bgTween:FlxTween = null;
	var leftPanel:FlxSprite;
	var rightPanel:FlxSprite;
	var selBar:FlxSprite;
	var chevron:FlxSprite;
	var ringA:FlxSprite;
	var ringB:FlxSprite;
	var beam:FlxSprite;
	var bigNum:FlxText;
	var nameText:FlxText;
	var descText:FlxText;
	var hintText:FlxText;
	var titleText:FlxText;

	var edTexts:Array<FlxText> = [];
	var edTextW:Array<Float> = [];
	var nodes:Array<FlxSprite> = [];
	var lerpSelected:Float = 0;

	var modFocus:Bool = false;
	var introProg:Float = 0;
	var animT:Float = 0;
	var descFull:String = '';
	var descShown:Float = 0;
	var selecting:Bool = false;
	var selectPulse:Float = 0;
	var selectDim:Float = 0;
	var holdTime:Float = 0;

	#if MODS_ALLOWED
	var modCard:FlxSprite;
	var modCardLeft:FlxSprite;
	var modCardTop:FlxSprite;
	var modTitle:FlxText;
	var modSub:FlxText;
	var modSep:FlxSprite;
	var modSel:FlxSprite;
	var modRows:Array<FlxText> = [];
	var modRowW:Array<Float> = [];
	var modScroll:Float = 0;
	var modSelY:Float = 0;
	var cardX:Float = 0;
	var cardWpx:Float = 330;
	#end

	inline function pin(o:FlxObject):Void
		o.scrollFactor.set();

	override function create()
	{
		FlxG.camera.bgColor = FlxColor.BLACK;
		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("Editors Main Menu", null);
		#end

		W = FlxG.width + MobileScaleMode.gameCutoutSize.x * 2;
		var H:Float = FlxG.height;
		var imgScale:Float = H / DESIGN_H;
		var aa:Bool = ClientPrefs.data.antialiasing;

		fontPath = Paths.font('vcr.ttf');
		if (Paths.fileExists('fonts/freeplay.otf', AssetType.FONT)) fontPath = Paths.font('freeplay.otf');
		else if (Paths.fileExists('fonts/freeplay.ttf', AssetType.FONT)) fontPath = Paths.font('freeplay.ttf');

		// El centro queda entre el panel izquierdo y la tarjeta de mods
		var rightLimit:Float = #if MODS_ALLOWED W - (CARD_W + 10) * imgScale #else W #end;
		centerX = (EDGE_X * imgScale + rightLimit) / 2;

		// ---------- Fondo (blanco/gris, se pinta con el color de cada editor) ----------
		bg = MenuBG.create('menuDesat');
		bg.color = colors[0];
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

		// ---------- Anillos HUD detrás del número ----------
		var ringSize:Int = 300;
		ringA = new FlxSprite().makeGraphic(ringSize, ringSize, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawRect(ringA, 3, 3, ringSize - 6, ringSize - 6, FlxColor.TRANSPARENT, {thickness: 3, color: ACCENT});
		ringA.antialiasing = true;
		ringA.setPosition(centerX - ringSize / 2, 200 - ringSize / 2);
		ringA.alpha = 0;
		pin(ringA);
		add(ringA);

		var ringSizeB:Int = 250;
		ringB = new FlxSprite().makeGraphic(ringSizeB, ringSizeB, FlxColor.TRANSPARENT, true);
		FlxSpriteUtil.drawRect(ringB, 3, 3, ringSizeB - 6, ringSizeB - 6, FlxColor.TRANSPARENT, {thickness: 2, color: ACCENT2});
		ringB.antialiasing = true;
		ringB.setPosition(centerX - ringSizeB / 2, 200 - ringSizeB / 2);
		ringB.angle = 45;
		ringB.alpha = 0;
		pin(ringB);
		add(ringB);

		beam = new FlxSprite(EDGE_X * imgScale, -4).makeGraphic(Std.int(rightLimit - EDGE_X * imgScale), 2, ACCENT);
		beam.alpha = 0.18;
		pin(beam);
		add(beam);

		// ---------- Número, nombre y descripción del editor elegido ----------
		bigNum = new FlxText(centerX - 150, 200 - 66, 300, '01', 110);
		bigNum.setFormat(fontPath, 110, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		bigNum.borderSize = 3;
		pin(bigNum);
		add(bigNum);

		nameText = new FlxText(centerX - 330, 372, 660, '', 40);
		nameText.setFormat(fontPath, 40, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		nameText.borderSize = 2;
		pin(nameText);
		add(nameText);

		descText = new FlxText(centerX - 300, 430, 600, '', 22);
		descText.setFormat(fontPath, 22, ACCENT, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		descText.borderSize = 1.5;
		pin(descText);
		add(descText);

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

		// ---------- Lista de editores: rombo + texto a su izquierda ----------
		for (i in 0...options.length)
		{
			var node:FlxSprite = new FlxSprite().makeGraphic(16, 16, FlxColor.WHITE);
			node.angle = 45;
			node.antialiasing = true;
			node.visible = false;
			pin(node);
			nodes.push(node);
			add(node);

			var t:FlxText = new FlxText(0, 0, 0, options[i], 32);
			t.setFormat(fontPath, 32, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			t.borderSize = 2;
			t.antialiasing = aa;
			t.visible = false;
			pin(t);
			edTextW.push(t.width);
			edTexts.push(t);
			add(t);
		}

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

		var titleY:Float = 24;
		titleText = new FlxText(panelTextX, titleY - rightPanel.height, 0, 'EDITORS', 26);
		titleText.setFormat(fontPath, 26, FlxColor.WHITE, LEFT);
		pin(titleText);
		add(titleText);

		var hdrY:Float = rightPanel.y;
		rightPanel.y = hdrY - rightPanel.height;
		FlxTween.tween(rightPanel, {y: hdrY}, 0.45, {startDelay: 0.15, ease: FlxEase.quartOut});
		FlxTween.tween(titleText, {y: titleY}, 0.45, {startDelay: 0.15, ease: FlxEase.quartOut});

		// ---------- Tarjeta de MODS (derecha, larga, con scroll) ----------
		#if MODS_ALLOWED
		for (folder in Mods.getModDirectories())
		{
			directories.push(folder);
		}

		var found:Int = directories.indexOf(Mods.currentModDirectory);
		if(found > -1) curDirectory = found;

		cardWpx = CARD_W * imgScale;
		cardX = W - cardWpx - 10 * imgScale;
		var cardY:Float = CARD_Y * imgScale;
		var cardH:Float = H - cardY - 16 * imgScale;

		modCard = new FlxSprite(cardX, cardY).makeGraphic(Std.int(cardWpx), Std.int(cardH), FlxColor.BLACK);
		modCard.alpha = 0.62;
		pin(modCard);
		add(modCard);

		modCardLeft = new FlxSprite(cardX, cardY).makeGraphic(3, Std.int(cardH), ACCENT);
		pin(modCardLeft);
		add(modCardLeft);

		modCardTop = new FlxSprite(cardX, cardY).makeGraphic(Std.int(cardWpx), 2, ACCENT);
		pin(modCardTop);
		add(modCardTop);

		modTitle = new FlxText(cardX + 22 * imgScale, cardY + 8 * imgScale, 0, 'MODS  ' + (directories.length - 1), 22);
		modTitle.setFormat(fontPath, 22, ACCENT, LEFT);
		pin(modTitle);
		add(modTitle);

		modSub = new FlxText(cardX + 22 * imgScale, cardY + 36 * imgScale, 0, '', 16);
		modSub.setFormat(fontPath, 16, FlxColor.WHITE, LEFT);
		pin(modSub);
		add(modSub);

		modSep = new FlxSprite(cardX + 14 * imgScale, (LIST_TOP - 8) * imgScale).makeGraphic(Std.int(cardWpx - 28 * imgScale), 1, ACCENT);
		modSep.alpha = 0.4;
		pin(modSep);
		add(modSep);

		modSel = new FlxSprite(cardX + 10 * imgScale, 0).makeGraphic(Std.int(cardWpx - 20 * imgScale), Std.int((MOD_ROW - 6) * imgScale), ACCENT);
		modSel.alpha = 0.15;
		pin(modSel);
		add(modSel);

		for (i in 0...directories.length)
		{
			var label:String = (directories[i] == null || directories[i].length < 1) ? 'NO MOD' : directories[i].toUpperCase();
			var t:FlxText = new FlxText(0, 0, 0, label, 24);
			t.setFormat(fontPath, 24, FlxColor.WHITE, LEFT);
			t.antialiasing = aa;
			t.visible = false;
			pin(t);
			modRowW.push(t.width);
			modRows.push(t);
			add(t);
		}

		applyDirectory();
		modSelY = LIST_TOP * imgScale + curDirectory * MOD_ROW * imgScale;
		#end

		// ---------- Ayuda abajo (sin barra negra) ----------
		hintText = new FlxText(EDGE_X * imgScale + 20, H - 40, rightLimit - EDGE_X * imgScale - 40, '', 18);
		hintText.setFormat(fontPath, 18, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		hintText.alpha = 0.8;
		pin(hintText);
		add(hintText);
		updateHint();

		var bgWarning:FlxText = MenuBG.warning();
		if (bgWarning != null) add(bgWarning);

		FlxG.mouse.visible = false;

		lerpSelected = curSelected;
		changeSelection(0, false);
		updateEditors(0);

		addTouchPad(#if MODS_ALLOWED 'LEFT_FULL' #else 'UP_DOWN' #end, 'A_B');

		super.create();
	}

	override function update(elapsed:Float)
	{
		animT += elapsed;

		if (!selecting)
		{
			// Mover en la lista activa (mantener pulsado repite)
			if (controls.UI_UP_P)
			{
				move(-1);
				holdTime = 0;
			}
			if (controls.UI_DOWN_P)
			{
				move(1);
				holdTime = 0;
			}
			if (controls.UI_UP || controls.UI_DOWN)
			{
				var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
				holdTime += elapsed;
				var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);
				if (holdTime > 0.5 && checkNewHold - checkLastHold > 0)
					move((checkNewHold - checkLastHold) * (controls.UI_UP ? -1 : 1));
			}
			if (FlxG.mouse.wheel != 0)
				move(-FlxG.mouse.wheel);

			#if MODS_ALLOWED
			if (controls.UI_RIGHT_P && !modFocus)
				setFocus(true);
			if (controls.UI_LEFT_P && modFocus)
				setFocus(false);
			#end

			if (controls.BACK)
			{
				if (modFocus) setFocus(false);
				else MusicBeatState.switchState(new MainMenuState());
			}

			if (controls.ACCEPT)
			{
				if (modFocus)
				{
					FlxG.sound.play(Paths.sound('confirmMenu'), 0.5);
					setFocus(false);
				}
				else playSelectAnimation();
			}
		}

		updateEditors(elapsed);
		#if MODS_ALLOWED
		updateMods(elapsed);
		#end
		updateAmbient(elapsed);

		super.update(elapsed);
	}

	inline function move(n:Int):Void
	{
		#if MODS_ALLOWED
		if (modFocus)
		{
			changeDirectory(n);
			return;
		}
		#end
		changeSelection(n);
	}

	function setFocus(f:Bool):Void
	{
		if (modFocus == f) return;
		modFocus = f;
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		updateHint();
	}

	function updateHint():Void
	{
		#if MODS_ALLOWED
		hintText.text = modFocus
			? '[UP/DOWN] Choose mod    [A] Confirm    [B / LEFT] Back'
			: '[UP/DOWN] Editors    [RIGHT] Mods    [A] Open    [B] Back';
		#else
		hintText.text = '[UP/DOWN] Editors    [A] Open    [B] Back';
		#end
	}

	// Anillos, rayo de escaneo, barra de selección y descripción que se escribe sola
	function updateAmbient(elapsed:Float):Void
	{
		ringA.angle += elapsed * 22;
		ringB.angle -= elapsed * 38;
		var rv:Float = FlxMath.bound((introProg - 0.35) / 0.65, 0, 1);
		ringA.alpha = 0.55 * rv;
		ringB.alpha = 0.4 * rv;
		beam.y += elapsed * 150;
		if (beam.y > FlxG.height) beam.y = -4;
		selBar.alpha = (modFocus ? 0.05 : (0.13 + 0.06 * Math.sin(animT * 4))) * rv;
		chevron.x = 10 + 4 * Math.sin(animT * 6);
		chevron.alpha = (modFocus ? 0.3 : 1) * rv;

		if (descShown < descFull.length)
		{
			descShown += elapsed * 90;
			descText.text = descFull.substr(0, Std.int(Math.min(descShown, descFull.length)));
		}
	}

	// Lista en curva: texto a la izquierda del rombo, que queda sobre el borde azul
	function updateEditors(elapsed:Float):Void
	{
		lerpSelected = FlxMath.lerp(curSelected, lerpSelected, Math.exp(-elapsed * 9.6));
		introProg = Math.min(1, introProg + elapsed / 1.0);

		var s:Float = FlxG.height / DESIGN_H;
		for (i in 0...options.length)
		{
			var d:Float = i - lerpSelected;
			var ad:Float = Math.abs(d);
			var item:FlxText = edTexts[i];
			var node:FlxSprite = nodes[i];
			item.visible = node.visible = ad < 5.5;
			if (!item.visible) continue;

			var isSel:Bool = (i == curSelected);
			var cy:Float = (SEL_Y + d * ROW_STEP) * s;
			var nodeCX:Float = (NODE_CX - ROW_CURVE * d * d) * s;
			if (isSel) nodeCX += 16 * s * selectPulse;
			var fade:Float = Math.max(0.2, Math.min(1, 1.15 - 0.28 * ad));
			if (!isSel) fade *= 1 - 0.75 * selectDim;

			// Entrada: cada fila llega desde la izquierda con retraso según su distancia
			var ie:Float = FlxEase.quartOut(FlxMath.bound(introProg * 1.8 - ad * 0.15, 0, 1));
			var slide:Float = -(1 - ie) * 260 * s;

			var ns:Float = (0.8 + 0.45 * Math.max(0, 1 - ad) + (isSel ? 0.8 * selectPulse : 0)) * s;
			node.scale.set(ns, ns);
			node.x = nodeCX - node.width / 2 + slide;
			node.y = cy - node.height / 2;
			node.color = isSel ? FlxColor.interpolate(ACCENT, FlxColor.WHITE, selectPulse) : FlxColor.fromInt(0xFF7F93A8);

			var avail:Float = nodeCX - 22 * s - 24 * s;
			var sc:Float = Math.max(0.3, Math.min(1, avail / edTextW[i]));
			item.scale.set(sc, sc);
			item.updateHitbox();
			item.x = nodeCX - 22 * s - item.width + slide;
			item.y = cy - item.height / 2;
			item.color = isSel ? FlxColor.interpolate(FlxColor.WHITE, ACCENT, selectPulse) : FlxColor.WHITE;

			item.alpha = node.alpha = fade * ie;
		}
	}

	#if MODS_ALLOWED
	// Lista larga de mods con scroll: la fila elegida se mantiene cerca del centro
	function updateMods(elapsed:Float):Void
	{
		var s:Float = FlxG.height / DESIGN_H;
		var ie:Float = FlxEase.quartOut(FlxMath.bound(introProg * 1.6 - 0.3, 0, 1));
		var off:Float = (1 - ie) * (cardWpx + 40 * s);

		modCard.x = modCardLeft.x = modCardTop.x = cardX + off;
		modTitle.x = modSub.x = cardX + 22 * s + off;
		modSep.x = cardX + 14 * s + off;
		modCard.alpha = 0.62 * ie;

		var rowH:Float = MOD_ROW * s;
		var regionTop:Float = LIST_TOP * s;
		var regionH:Float = LIST_BOTTOM * s - regionTop;
		var maxScroll:Float = Math.max(0, directories.length * rowH - regionH);
		var target:Float = FlxMath.bound((curDirectory + 0.5) * rowH - regionH / 2, 0, maxScroll);
		modScroll = FlxMath.lerp(target, modScroll, Math.exp(-elapsed * 10));

		for (i in 0...directories.length)
		{
			var t:FlxText = modRows[i];
			var y:Float = regionTop + i * rowH - modScroll;
			var cyRow:Float = y + rowH / 2;
			var edge:Float = Math.min(cyRow - regionTop, regionTop + regionH - cyRow);
			t.visible = edge > 0;
			if (!t.visible) continue;

			var fade:Float = FlxMath.bound(edge / (rowH * 0.7), 0, 1);
			var isSel:Bool = (i == curDirectory);
			var avail:Float = cardWpx - 56 * s;
			var sc:Float = Math.max(0.5, Math.min(1, avail / modRowW[i]));
			t.scale.set(sc, sc);
			t.updateHitbox();
			t.x = cardX + 28 * s + off;
			t.y = cyRow - t.height / 2;
			t.color = isSel ? 0xFFFFFFFF : 0xFFBFD0E0;
			t.alpha = (isSel ? 1 : 0.65) * fade * ie;
		}

		// Barra de selección: sigue a la fila elegida; más fuerte cuando la lista de mods está activa
		var selTarget:Float = regionTop + curDirectory * rowH - modScroll + 3 * s;
		modSelY = FlxMath.lerp(selTarget, modSelY, Math.exp(-elapsed * 18));
		modSel.x = cardX + 10 * s + off;
		modSel.y = modSelY;
		modSel.alpha = (modFocus ? 0.32 + 0.1 * Math.sin(animT * 5) : 0.14) * ie;
		modCardLeft.alpha = modFocus ? 1 : 0.45;
		modCardTop.alpha = modFocus ? 1 : 0.45;
	}

	// Aplica el mod elegido (igual que antes, pero sin la barra negra)
	function applyDirectory():Void
	{
		WeekData.setDirectoryFromWeek();
		var label:String;
		if(directories[curDirectory] == null || directories[curDirectory].length < 1)
			label = 'NO MOD DIRECTORY LOADED';
		else
		{
			Mods.currentModDirectory = directories[curDirectory];
			label = 'LOADED: ' + Mods.currentModDirectory.toUpperCase();
		}
		if (label.length > 26) label = label.substr(0, 24) + '..';
		modSub.text = label;
	}

	function changeDirectory(change:Int = 0)
	{
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		curDirectory += change;

		if(curDirectory < 0)
			curDirectory = directories.length - 1;
		if(curDirectory >= directories.length)
			curDirectory = 0;

		applyDirectory();
	}
	#end

	function changeSelection(change:Int = 0, playSound:Bool = true)
	{
		if (playSound) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		curSelected = FlxMath.wrap(curSelected + change, 0, options.length - 1);

		// Fondo: se pinta con el color del editor
		var target:Int = colors[curSelected];
		if (bgTween != null) bgTween.cancel();
		bgTween = FlxTween.color(bg, 0.5, bg.color, target);

		// Número que "salta", nombre que sube un poco y descripción que se escribe sola
		bigNum.text = (curSelected + 1 < 10 ? '0' : '') + (curSelected + 1);
		FlxTween.cancelTweensOf(bigNum.scale);
		bigNum.scale.set(0.7, 0.7);
		FlxTween.tween(bigNum.scale, {x: 1, y: 1}, 0.35, {ease: FlxEase.backOut});

		nameText.text = options[curSelected];
		FlxTween.cancelTweensOf(nameText);
		nameText.alpha = 0;
		nameText.y = 384;
		FlxTween.tween(nameText, {alpha: 1, y: 372}, 0.25, {ease: FlxEase.quartOut});

		descFull = descriptions[curSelected];
		descShown = 0;
		descText.text = '';
	}

	// Animación de "select": el editor elegido salta, los demás se apagan, destello, y luego se abre
	function playSelectAnimation():Void
	{
		selecting = true;
		FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);

		FlxTween.num(0, 1, 0.12, {ease: FlxEase.quadOut, onComplete: function(_)
		{
			FlxTween.num(1, 0, 0.4, {ease: FlxEase.quadOut}, function(v:Float) selectPulse = v);
		}}, function(v:Float) selectPulse = v);
		FlxTween.num(0, 1, 0.3, {ease: FlxEase.quadOut}, function(v:Float) selectDim = v);

		FlxTween.cancelTweensOf(bigNum.scale);
		bigNum.scale.set(1.25, 1.25);
		FlxTween.tween(bigNum.scale, {x: 1, y: 1}, 0.4, {ease: FlxEase.backOut});

		var flash:FlxSprite = new FlxSprite().makeGraphic(Std.int(W), FlxG.height, FlxColor.WHITE);
		flash.scrollFactor.set();
		flash.alpha = 0.3;
		add(flash);
		FlxTween.tween(flash, {alpha: 0}, 0.4, {ease: FlxEase.quadOut, onComplete: function(_) {
			remove(flash, true);
			flash.destroy();
		}});

		new FlxTimer().start(0.5, function(_) openEditor());
	}

	function openEditor():Void
	{
		switch(options[curSelected]) {
			case 'Chart Editor'://felt it would be cool maybe
				LoadingState.loadAndSwitchState(new ChartingState(), false);
			case 'Character Editor':
				LoadingState.loadAndSwitchState(new CharacterEditorState(Character.DEFAULT_CHARACTER, false));
			case 'Stage Editor':
				LoadingState.loadAndSwitchState(new StageEditorState());
			case 'Week Editor':
				MusicBeatState.switchState(new WeekEditorState());
			case 'Menu Character Editor':
				MusicBeatState.switchState(new MenuCharacterEditorState());
			case 'Dialogue Editor':
				LoadingState.loadAndSwitchState(new DialogueEditorState(), false);
			case 'Dialogue Portrait Editor':
				LoadingState.loadAndSwitchState(new DialogueCharacterEditorState(), false);
			case 'Note Splash Editor':
				MusicBeatState.switchState(new NoteSplashEditorState());
			case 'Menu Editor':
				MusicBeatState.switchState(new MenuEditorState());
			case 'Credits Editor':
				MusicBeatState.switchState(new CreditsEditorState());
		}
		FlxG.sound.music.volume = 0;
		FreeplayState.destroyFreeplayVocals();
	}
}
