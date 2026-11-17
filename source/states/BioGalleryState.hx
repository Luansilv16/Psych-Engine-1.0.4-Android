package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxSpriteUtil;
import haxe.Json;
import mobile.backend.MobileScaleMode;
import objects.HealthIcon;
import objects.Neon;
import openfl.utils.AssetType;

typedef BioEntry =
{
	var name:String;
	var icon:String;    // nombre del icono (images/icons/icon-NOMBRE.png)
	var image:String;   // retrato grande (images/RUTA.png). Si no existe, se muestra el icono grande
	var role:String;
	var bio:String;
	var details:String; // segunda página (datos)
	var accent:FlxColor;
}

/**
 * Galería de biografías estilo neón.
 * - Se llena desde data/bios.json (editable y compatible con mods).
 * - Abajo hay una tira de iconos: tocar/seleccionar un icono muestra su bio.
 * - A (o tocar la pestaña) cambia entre HISTORIA y DATOS.
 */
class BioGalleryState extends MusicBeatState
{
	public static var curSelected:Int = 0;

	var bios:Array<BioEntry> = [];
	var icons:Array<HealthIcon> = [];
	var iconCX:Array<Float> = [];

	var portraitPanel:FlxSprite;
	var portraitGlow:FlxSprite;
	var infoPanel:FlxSprite;
	var portrait:FlxSprite;
	var noImageText:FlxText;
	var bigIcon:HealthIcon;
	var iconFrame:FlxSprite;
	var divider:FlxSprite;
	var scanBar:FlxSprite;
	var ring:FlxSprite;

	var nameText:FlxText;
	var roleText:FlxText;
	var tabText:FlxText;
	var bioText:FlxText;
	var counterText:FlxText;
	var leftArrow:FlxText;
	var rightArrow:FlxText;

	var page:Int = 0;
	var fullBio:String = '';
	var typed:Float = 0;
	var shown:Int = -1;
	var scanTime:Float = 0;
	var leaving:Bool = false;

	static inline var STRIP_Y:Float = 460;
	static inline var STRIP_H:Float = 120;
	static inline var ICON_SPACING:Float = 125;

	override function create()
	{
		super.create();

		#if MODS_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Leyendo biografias", null);
		#end

		persistentUpdate = persistentDraw = true;

		loadBios();
		if (curSelected >= bios.length) curSelected = 0;

		var wx:Float = Neon.wideX();
		var ww:Int = Neon.wideW();

		// ---- Fondo ----
		var bg:FlxSprite = Neon.gradient(ww, FlxG.height);
		bg.x = wx;
		bg.scrollFactor.set();
		add(bg);
		add(Neon.scanlines(ww, FlxG.height, wx));

		// ---- Titulo ----
		var title:FlxText = Neon.styleText(new FlxText(wx + 60, 20, 0, 'ARCHIVO DE PERSONAJES'), Neon.MAGENTA, 34);
		add(title);

		counterText = Neon.styleText(new FlxText(0, 28, 0, ''), Neon.CYAN, 24);
		add(counterText);

		var line:FlxSprite = new FlxSprite(wx + 60, 74).makeGraphic(ww - 120, 3, Neon.CYAN);
		line.alpha = 0.8;
		add(line);

		// ---- Paneles ----
		portraitPanel = Neon.panel(300, 350, Neon.CYAN);
		portraitPanel.setPosition(70, 95);
		add(portraitPanel);

		portraitGlow = new FlxSprite(portraitPanel.x + 8, portraitPanel.y + 8).makeGraphic(284, 334, FlxColor.WHITE);
		portraitGlow.alpha = 0.1;
		add(portraitGlow);

		infoPanel = Neon.panel(810, 350, Neon.MAGENTA);
		infoPanel.setPosition(400, 95);
		add(infoPanel);

		portrait = new FlxSprite();
		portrait.scrollFactor.set();
		add(portrait);

		noImageText = Neon.styleText(new FlxText(portraitPanel.x, portraitPanel.y + 160, portraitPanel.width, 'SIN IMAGEN'), Neon.DIM, 22);
		noImageText.alignment = CENTER;
		noImageText.visible = false;
		add(noImageText);

		scanBar = new FlxSprite(portraitPanel.x + 8, portraitPanel.y + 10).makeGraphic(Std.int(portraitPanel.width) - 16, 3, Neon.CYAN);
		scanBar.alpha = 0.35;
		add(scanBar);

		// ---- Info: icono + nombre ----
		iconFrame = new FlxSprite(infoPanel.x + 24, infoPanel.y + 18).makeGraphic(110, 110, FlxColor.TRANSPARENT, true);
		add(iconFrame);

		nameText = Neon.styleText(new FlxText(infoPanel.x + 156, infoPanel.y + 24, 520, ''), Neon.MAGENTA, 44);
		add(nameText);

		roleText = Neon.styleText(new FlxText(infoPanel.x + 158, infoPanel.y + 80, 520, ''), Neon.CYAN, 22);
		add(roleText);

		tabText = Neon.styleText(new FlxText(infoPanel.x + infoPanel.width - 190, infoPanel.y + 26, 160, 'HISTORIA'), Neon.CYAN, 22);
		tabText.alignment = RIGHT;
		add(tabText);

		divider = new FlxSprite(infoPanel.x + 26, infoPanel.y + 148).makeGraphic(Std.int(infoPanel.width) - 52, 2, FlxColor.WHITE);
		divider.alpha = 0.6;
		add(divider);

		bioText = new FlxText(infoPanel.x + 28, infoPanel.y + 164, infoPanel.width - 56, '');
		bioText.setFormat(Paths.font('vcr.ttf'), 24, Neon.TEXT, LEFT);
		add(bioText);

		// ---- Tira de iconos ----
		var stripPanel:FlxSprite = Neon.panel(ww - 60, Std.int(STRIP_H), Neon.BLUE);
		stripPanel.setPosition(wx + 30, STRIP_Y);
		add(stripPanel);

		var cy:Float = STRIP_Y + STRIP_H / 2;

		ring = new FlxSprite(FlxG.width / 2 - 62, cy - 62).makeGraphic(124, 124, FlxColor.TRANSPARENT, true);
		add(ring);

		for (i in 0...bios.length)
		{
			var ic:HealthIcon = new HealthIcon(bios[i].icon);
			ic.scrollFactor.set();
			add(ic);
			icons.push(ic);
			iconCX.push(FlxG.width / 2 + (i - curSelected) * ICON_SPACING);
		}

		leftArrow = Neon.styleText(new FlxText(wx + 48, cy - 28, 0, '<'), Neon.MAGENTA, 52);
		rightArrow = Neon.styleText(new FlxText(wx + ww - 48 - 30, cy - 28, 0, '>'), Neon.MAGENTA, 52);
		add(leftArrow);
		add(rightArrow);

		selectIndex(curSelected, true);

		addTouchPad('LEFT_RIGHT', 'A_B');
	}

	// ------------------------------------------------------------------
	// Datos
	// ------------------------------------------------------------------

	function loadBios():Void
	{
		var loaded:Bool = false;
		try
		{
			if (Paths.fileExists('data/bios.json', AssetType.TEXT))
			{
				var data:Dynamic = Json.parse(Paths.getTextFromFile('data/bios.json'));
				var list:Array<Dynamic> = data.characters;
				for (e in list)
				{
					var idx:Int = bios.length;
					var acc:FlxColor = Neon.accentFor(idx);
					if (e.color != null)
					{
						var parsed:Null<FlxColor> = FlxColor.fromString(Std.string(e.color));
						if (parsed != null)
						{
							acc = parsed;
							acc.alpha = 255;
						}
					}

					var det:String = '';
					if (e.details != null)
					{
						var arr:Array<Dynamic> = e.details;
						det = arr.join('\n');
					}

					bios.push({
						name: (e.name != null) ? Std.string(e.name) : '???',
						icon: (e.icon != null) ? Std.string(e.icon) : 'face',
						image: (e.image != null) ? Std.string(e.image) : 'bio/' + ((e.icon != null) ? Std.string(e.icon) : 'face'),
						role: (e.role != null) ? Std.string(e.role) : '',
						bio: (e.bio != null) ? Std.string(e.bio) : '',
						details: det,
						accent: acc
					});
					loaded = true;
				}
			}
		}
		catch (e:Dynamic)
		{
			trace('bios.json tiene un error: ' + e);
			loaded = false;
		}

		if (!loaded || bios.length == 0)
		{
			bios = [];
			bios.push(make('Boyfriend', 'bf', 'Rapero / Protagonista',
				'Un chico con gorra y mucho ritmo que enfrenta a cualquiera que se le ponga enfrente en una batalla de rap, todo por el amor de Girlfriend.',
				'Edad: 16\nDuo: Girlfriend\nHabilidad: Beat Box', Neon.CYAN));
			bios.push(make('Girlfriend', 'gf', 'Novia de Boyfriend / DJ',
				'Siempre esta sentada sobre las bocinas llevando el ritmo de cada cancion. Aunque no lo parezca, es quien mantiene todo el espectaculo en pie.',
				'Edad: 16\nDuo: Boyfriend\nLugar favorito: Sobre las bocinas', Neon.MAGENTA));
			bios.push(make('Daddy Dearest', 'dad', 'Ex estrella del rock',
				'Padre de Girlfriend y exestrella del rock. No soporta que su hija salga con un chico que solo sabe hacer ruido con un microfono.',
				'Hija: Girlfriend\nEsposa: Mommy Mearest', 0xFFAF66CE));
		}
	}

	function make(name:String, icon:String, role:String, bio:String, details:String, accent:FlxColor):BioEntry
	{
		return {
			name: name,
			icon: icon,
			image: 'bio/' + icon,
			role: role,
			bio: bio,
			details: details,
			accent: accent
		};
	}

	// ------------------------------------------------------------------
	// Seleccion
	// ------------------------------------------------------------------

	function changeItem(change:Int):Void
	{
		selectIndex(FlxMath.wrap(curSelected + change, 0, bios.length - 1));
	}

	function selectIndex(idx:Int, silent:Bool = false):Void
	{
		curSelected = idx;
		page = 0;
		var b:BioEntry = bios[idx];

		if (!silent)
			FlxG.sound.play(Paths.sound('scrollMenu'));

		drawRing(b.accent);
		drawIconFrame(b.accent);

		nameText.text = b.name.toUpperCase();
		nameText.borderColor = b.accent;
		roleText.text = b.role;

		FlxTween.cancelTweensOf(divider);
		FlxTween.cancelTweensOf(portraitGlow);
		if (silent)
		{
			divider.color = b.accent;
			portraitGlow.color = b.accent;
		}
		else
		{
			FlxTween.color(divider, 0.25, divider.color, b.accent);
			FlxTween.color(portraitGlow, 0.25, portraitGlow.color, b.accent);
		}

		counterText.text = pad(idx + 1) + ' / ' + pad(bios.length);
		counterText.x = Neon.wideX() + Neon.wideW() - 60 - counterText.width;

		loadPortrait(b);
		showPage();
	}

	function showPage():Void
	{
		var b:BioEntry = bios[curSelected];
		tabText.text = (page == 0) ? 'HISTORIA' : 'DATOS';
		fullBio = (page == 0) ? b.bio : (b.details != '' ? b.details : 'Sin datos registrados.');

		// Ajusta el tamano de letra para que el texto quepa en el panel (vcr es monoespaciada)
		var sz:Int = 24;
		while (sz > 16)
		{
			var cpl:Int = Std.int(bioText.fieldWidth / (sz * 0.62));
			var lines:Int = Math.ceil(fullBio.length / Math.max(1, cpl)) + (fullBio.split('\n').length - 1);
			if (lines * sz * 1.25 <= 170) break;
			sz--;
		}
		bioText.size = sz;

		typed = 0;
		shown = -1;
		bioText.text = '';
	}

	function togglePage():Void
	{
		page = (page == 0) ? 1 : 0;
		FlxG.sound.play(Paths.sound('confirmMenu'), 0.6);
		showPage();
	}

	function loadPortrait(b:BioEntry):Void
	{
		// Icono del personaje (siempre se muestra junto al nombre)
		if (bigIcon != null)
		{
			remove(bigIcon, true);
			bigIcon.destroy();
			bigIcon = null;
		}
		bigIcon = new HealthIcon(b.icon);
		bigIcon.scrollFactor.set();
		bigIcon.scale.set(0.6, 0.6);
		bigIcon.updateHitbox();
		bigIcon.setPosition(iconFrame.x + (iconFrame.width - bigIcon.width) / 2, iconFrame.y + (iconFrame.height - bigIcon.height) / 2);
		bigIcon.alpha = 0;
		add(bigIcon);
		FlxTween.tween(bigIcon, {alpha: 1}, 0.25);

		// PNG grande del personaje
		FlxTween.cancelTweensOf(portrait);
		if (b.image != '' && Paths.fileExists('images/' + b.image + '.png', AssetType.IMAGE))
		{
			noImageText.visible = false;
			portrait.visible = true;
			portrait.loadGraphic(Paths.image(b.image));
			var s:Float = Math.min((portraitPanel.width - 40) / portrait.frameWidth, (portraitPanel.height - 40) / portrait.frameHeight);
			portrait.scale.set(s, s);
			portrait.updateHitbox();
			portrait.antialiasing = ClientPrefs.data.antialiasing;
			portrait.setPosition(portraitPanel.x + (portraitPanel.width - portrait.width) / 2,
				portraitPanel.y + (portraitPanel.height - portrait.height) / 2);

			// Entrada suave
			var tx:Float = portrait.x;
			portrait.x = tx - 30;
			portrait.alpha = 0;
			FlxTween.tween(portrait, {alpha: 1, x: tx}, 0.3, {ease: FlxEase.quadOut});
		}
		else
		{
			portrait.visible = false;
			noImageText.visible = true;
		}
	}

	function drawIconFrame(color:FlxColor):Void
	{
		FlxSpriteUtil.fill(iconFrame, FlxColor.TRANSPARENT);
		FlxSpriteUtil.drawRoundRect(iconFrame, 2, 2, 106, 106, 16, 16, 0x44000000, {thickness: 3, color: color});
	}

	function drawRing(color:FlxColor):Void
	{
		FlxSpriteUtil.fill(ring, FlxColor.TRANSPARENT);
		FlxSpriteUtil.drawRoundRect(ring, 2, 2, 120, 120, 18, 18, 0x22FFFFFF, {thickness: 3, color: color});
	}

	inline function pad(n:Int):String
		return (n < 10 ? '0' : '') + n;

	inline function lerpTo(a:Float, b:Float, t:Float):Float
		return a + (b - a) * Math.min(1, t);

	// ------------------------------------------------------------------
	// Update
	// ------------------------------------------------------------------

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		// Barra de escaneo del retrato
		scanTime += elapsed;
		scanBar.y = portraitPanel.y + 10 + ((scanTime * 110) % (portraitPanel.height - 24));

		// Iconos de la tira
		var cy:Float = STRIP_Y + STRIP_H / 2;
		var halfView:Float = Neon.wideW() / 2 - 90;
		for (i in 0...icons.length)
		{
			var off:Int = i - curSelected;
			var ic:HealthIcon = icons[i];
			var isSel:Bool = (off == 0);

			iconCX[i] = lerpTo(iconCX[i], FlxG.width / 2 + off * ICON_SPACING, elapsed * 12);

			var sc:Float = lerpTo(ic.scale.x, isSel ? 0.7 : 0.48, elapsed * 14);
			ic.scale.set(sc, sc);
			ic.updateHitbox();
			ic.setPosition(iconCX[i] - ic.width / 2, cy - ic.height / 2);

			var visibleInStrip:Bool = Math.abs(iconCX[i] - FlxG.width / 2) <= halfView;
			ic.alpha = visibleInStrip ? (isSel ? 1 : 0.55) : 0;
		}

		// Texto que se escribe poco a poco
		if (shown < fullBio.length)
		{
			typed += elapsed * 140;
			var n:Int = Std.int(Math.min(fullBio.length, typed));
			if (n != shown)
			{
				shown = n;
				bioText.text = fullBio.substr(0, n);
			}
		}

		if (leaving) return;

		// Teclado / botones tactiles
		if (controls.UI_LEFT_P) changeItem(-1);
		if (controls.UI_RIGHT_P) changeItem(1);
		if (controls.ACCEPT) togglePage();

		if (controls.BACK)
		{
			leaving = true;
			FlxG.sound.play(Paths.sound('cancelMenu'));
			MusicBeatState.switchState(new MainMenuState());
			return;
		}

		// Toque / mouse
		if (FlxG.mouse.justPressed)
		{
			if (FlxG.mouse.overlaps(leftArrow, FlxG.camera)) { changeItem(-1); return; }
			if (FlxG.mouse.overlaps(rightArrow, FlxG.camera)) { changeItem(1); return; }
			if (FlxG.mouse.overlaps(tabText, FlxG.camera)) { togglePage(); return; }

			for (i in 0...icons.length)
			{
				if (icons[i].alpha > 0.1 && FlxG.mouse.overlaps(icons[i], FlxG.camera))
				{
					if (i == curSelected) togglePage();
					else selectIndex(i);
					break;
				}
			}
		}
	}
}
