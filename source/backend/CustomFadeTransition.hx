package backend;

import flixel.FlxSubState;
import flixel.FlxCamera;
import flixel.math.FlxMath;
import flixel.tweens.FlxEase;
import flixel.graphics.FlxGraphic;
import openfl.display.BitmapData;
import openfl.geom.Point;
import mobile.backend.MobileScaleMode;
import objects.Neon;

/**
 * Transición futurista NixerEngine (persianas digitales + panel de carga)
 *
 * - transOut (isTransIn = false): 14 barras entran desde los lados, en orden mezclado,
 *   con borde cian/magenta, hasta tapar toda la pantalla. Después aparece el panel:
 *   logo con efecto glitch, icono, barra de carga y un tip del engine con efecto máquina de escribir.
 * - transIn (isTransIn = true): empieza con todo tapado y las barras se abren
 *   descubriendo el nuevo estado. El panel se queda un momento y se desvanece.
 *   El mismo tip se mantiene entre la cobertura y la apertura.
 *
 * Compatible con Wide Screen Mode ON/OFF.
 *
 * Imágenes (en images/): NixerEngineLogoTweak.png (logo), iconOG.png (icono) y check.png
 * (patrón de cuadros animado de fondo). Si el logo falta se usa logoBumpin; si el icono falta
 * se prueba nixerIcon, icon e icons/icon-face; si check.png falta, no hay patrón.
 */
class CustomFadeTransition extends FlxSubState {
	public static var finishCallback:Void->Void;

	// Tips y curiosidades (se elige uno al azar en cada transición)
	static final TIPS:Array<String> = [
		"NixerEngine fue hecho por un furry: 100% de amor por los menús neón y 0% de vergüenza.",
		"En la pantalla de título, izquierda o derecha cambia el color del logo.",
		"Dato curioso: este engine se programó con orejitas puestas. No afecta el rendimiento (creo).",
		"Hold Splash, en las opciones de Visuals, muestra splashes estilo V-Slice y respeta tus colores RGB.",
		"Si el juego tarda en cargar, es porque está ronroneando... digo, compilando shaders.",
		"Puedes activar o desactivar el Modo Pantalla Ancha desde Opciones, sin reiniciar el juego.",
		"Colors Settings cambia los colores de tus notas, y los hold splashes los copian.",
		"Nyxen recomienda: hidrátate, estira la cola y revisa los logs de GitHub.",
		"Mover o activar un mod desde el menú de mods reinicia el juego.",
		"NixerEngine nació de Psych Engine, así que muchos mods de Psych deberían funcionar.",
		"Nixer: nombre corto, bugs largos.",
		"Si desactivas Flashing Lights, los destellos del engine se vuelven mucho más suaves.",
		"En el modo historia puedes reiniciar el puntaje de una semana desde su menú.",
		"Si algo se rompe, mira el log. Si sigue roto, mira el log otra vez.",
		"El zorro del código dice: guarda tus cambios antes de que Haxe se enoje."
	];

	static var currentTip:String = null;
	static var currentTipIdx:Int = -1;

	var isTransIn:Bool = false;
	var duration:Float;

	var transCam:FlxCamera;
	var bars:Array<FlxSprite> = [];
	var edges:Array<FlxSprite> = [];
	var trails:Array<FlxSprite> = [];
	var delays:Array<Float> = [];
	var scanLine:FlxSprite;

	// Panel de carga
	var hud:Array<FlxSprite> = [];
	var hudBase:Array<Float> = [];
	var logo:FlxSprite;
	var ghostM:FlxSprite;
	var ghostC:FlxSprite;
	var icon:FlxSprite;
	var fill:FlxSprite;
	var statusText:FlxText;
	var tipText:FlxText;
	var logoX:Float = 0;
	var logoStatic:Bool = false;
	var logoBase:Float = 1;
	var bumpScale:Float = 1;
	var checker:FlxSprite;
	var checkW:Int = 150;
	var checkH:Int = 149;
	var panelX:Float = 0;
	var lastBump:Float = -1;
	var lastChars:Int = -1;
	var lastDots:Int = -1;

	var time:Float = 0;
	var closing:Bool = false;
	var width:Int = 1280;
	var height:Int = 720;

	static inline var BAR_COUNT:Int = 14;
	static inline var STAGGER:Float = 0.4;  // parte de la duración usada para escalonar las barras
	static inline var EDGE_W:Int = 4;
	static inline var PANEL_W:Int = 760;
	static inline var TRACK_Y:Int = 372;

	public function new(duration:Float, isTransIn:Bool)
	{
		this.duration = Math.max(0.01, duration);
		this.isTransIn = isTransIn;
		super();
	}

	static function pickTip():Void
	{
		var idx:Int = FlxG.random.int(0, TIPS.length - 1);
		if (idx == currentTipIdx && TIPS.length > 1) idx = (idx + 1) % TIPS.length;
		currentTipIdx = idx;
		currentTip = TIPS[idx];
	}

	function addHud(spr:FlxSprite, base:Float = 1):FlxSprite
	{
		spr.scrollFactor.set();
		spr.alpha = isTransIn ? base : 0;
		hud.push(spr);
		hudBase.push(base);
		add(spr);
		return spr;
	}

	function makeText(x:Float, y:Float, w:Float, txt:String, size:Int, color:FlxColor, align:FlxTextAlign):FlxText
	{
		var t:FlxText = new FlxText(x, y, w, txt, size);
		t.setFormat(Paths.font('vcr.ttf'), size, color, align);
		return t;
	}

	/** Esquina estilo HUD: dos líneas finas en L. sx/sy = dirección (1 ó -1). */
	function addBracket(x:Float, y:Float, sx:Int, sy:Int):Void
	{
		var h:FlxSprite = new FlxSprite(sx > 0 ? x : x - 40, sy > 0 ? y : y - 3).makeGraphic(40, 3, Neon.CYAN);
		var v:FlxSprite = new FlxSprite(sx > 0 ? x : x - 3, sy > 0 ? y : y - 40).makeGraphic(3, 40, Neon.CYAN);
		addHud(h, 0.8);
		addHud(v, 0.8);
	}

	function buildPanel():Void
	{
		panelX = (width - PANEL_W) / 2;

		// Patrón de cuadros animado (debajo de todo el panel)
		checker = makeChecker();
		if (checker != null) addHud(checker, 0.14);

		// Esquinas del HUD y textos pequeños
		addBracket(24, 24, 1, 1);
		addBracket(width - 24, 24, -1, 1);
		addBracket(24, height - 24, 1, -1);
		addBracket(width - 24, height - 24, -1, -1);
		addHud(makeText(34, 36, 400, "NIXERENGINE // SYSTEM LINK", 14, Neon.DIM, LEFT));
		addHud(makeText(width - 34 - 400, height - 52, 400, "BY NYXEN ROARING", 14, Neon.MAGENTA, RIGHT));

		// Logo con aberración cromática (copias magenta y cian detrás)
		logoStatic = Paths.fileExists('images/NixerEngineLogoTweak.png', IMAGE);
		var frames = logoStatic ? null : Paths.getSparrowAtlas('logoBumpin');
		if (logoStatic || frames != null)
		{
			ghostM = makeLogoSprite(frames, Neon.MAGENTA);
			ghostC = makeLogoSprite(frames, Neon.CYAN);
			logo = makeLogoSprite(frames, FlxColor.WHITE);
			logoX = (width - logo.width) / 2;
			logoBase = logo.scale.x;
			for (g in [ghostM, ghostC, logo])
			{
				g.x = logoX;
				g.y = 70;
			}
			ghostM.blend = ADD;
			ghostC.blend = ADD;
			addHud(ghostM, 0.45);
			addHud(ghostC, 0.45);
			addHud(logo);
		}

		// Fila de estado: icono + texto CARGANDO
		icon = makeIcon();
		if (icon != null)
		{
			icon.x = panelX;
			icon.y = 304;
			addHud(icon);
		}
		statusText = makeText(panelX + (icon != null ? icon.width + 16 : 0), 322, 400, "CARGANDO", 22, Neon.CYAN, LEFT);
		addHud(statusText);

		// Barra de progreso
		var track:FlxSprite = new FlxSprite(panelX, TRACK_Y).makeGraphic(PANEL_W, 6, 0xFF1A1840);
		addHud(track);
		fill = new FlxSprite(panelX, TRACK_Y).makeGraphic(1, 1, Neon.MAGENTA);
		fill.scale.set(1, 6);
		fill.updateHitbox();
		addHud(fill);

		// Panel del tip
		var panel:FlxSprite = Neon.panel(PANEL_W, 150, Neon.CYAN);
		panel.setPosition(panelX, 410);
		addHud(panel);

		addHud(Neon.styleText(new FlxText(panelX + 24, 424, 400, "TIP #" + (currentTipIdx + 1) + " / " + TIPS.length), Neon.MAGENTA, 18));

		tipText = makeText(panelX + 24, 456, PANEL_W - 48, "", 24, Neon.TEXT, LEFT);
		addHud(tipText);
	}

	function makeLogoSprite(frames:flixel.graphics.frames.FlxAtlasFrames, color:FlxColor):FlxSprite
	{
		var s:FlxSprite = new FlxSprite();
		if (logoStatic)
			s.loadGraphic(Paths.image('NixerEngineLogoTweak'));
		else
		{
			s.frames = frames;
			s.animation.addByPrefix('bump', 'logo bumpin', 24, false);
			s.animation.play('bump');
		}
		s.antialiasing = ClientPrefs.data.antialiasing;
		s.setGraphicSize(0, logoStatic ? 210 : 190);
		s.updateHitbox();
		s.color = color;
		return s;
	}

	/** Patrón de cuadros a partir de check.png, repetido para cubrir toda la pantalla. */
	function makeChecker():FlxSprite
	{
		if (!Paths.fileExists('images/check.png', IMAGE)) return null;

		var g:FlxGraphic = Paths.image('check');
		if (g == null || g.bitmap == null || g.bitmap.image == null) return null; // sin datos (cache en GPU)

		var src:BitmapData = g.bitmap;
		checkW = src.width;
		checkH = src.height;

		var bmp:BitmapData = new BitmapData(width + checkW, height + checkH, true, 0x00000000);
		var pt:Point = new Point();
		var py:Int = 0;
		while (py < bmp.height)
		{
			var px:Int = 0;
			while (px < bmp.width)
			{
				pt.setTo(px, py);
				bmp.copyPixels(src, src.rect, pt);
				px += checkW;
			}
			py += checkH;
		}

		var s:FlxSprite = new FlxSprite().loadGraphic(FlxGraphic.fromBitmapData(bmp, true));
		s.color = Neon.BLUE;
		return s;
	}

	function makeIcon():FlxSprite
	{
		for (name in ['iconOG', 'nixerIcon', 'icon', 'icons/icon-face'])
		{
			if (!Paths.fileExists('images/' + name + '.png', IMAGE)) continue;

			var s:FlxSprite = new FlxSprite().loadGraphic(Paths.image(name));
			// Los iconos de vida traen 2 frames lado a lado: se usa solo el primero
			if (s.width > s.height * 1.5)
			{
				s.loadGraphic(Paths.image(name), true, Std.int(s.width / 2), Std.int(s.height));
				s.animation.add('i', [0], 1, false);
				s.animation.play('i');
			}
			s.antialiasing = ClientPrefs.data.antialiasing;
			s.setGraphicSize(0, 64);
			s.updateHitbox();
			return s;
		}
		return null;
	}

	override function create()
	{
		// Ancho real de pantalla (incluye cutouts / wide mode)
		width = FlxG.width + Std.int(MobileScaleMode.gameCutoutSize.x) * 2;
		height = FlxG.height;

		// El tip se elige al cubrir; al descubrir se mantiene el mismo
		if (!isTransIn || currentTip == null) pickTip();

		transCam = new FlxCamera(0, 0, width, height);
		transCam.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(transCam, false);
		cameras = [transCam];

		var barH:Float = height / BAR_COUNT;
		var barPx:Int = Math.ceil(barH) + 1;

		for (i in 0...BAR_COUNT)
		{
			var dir:Int = (i % 2 == 0) ? 1 : -1;

			var bar:FlxSprite = new FlxSprite(0, Math.floor(i * barH)).makeGraphic(width, barPx, Neon.BG);
			bar.scrollFactor.set();
			// Cubrir: arrancan fuera de pantalla. Descubrir: arrancan tapando todo.
			bar.x = isTransIn ? 0 : -dir * width;
			bars.push(bar);
			add(bar);

			var trail:FlxSprite = new FlxSprite(0, bar.y).makeGraphic(EDGE_W, barPx, Neon.MAGENTA);
			trail.scrollFactor.set();
			trail.alpha = 0.5;
			trail.visible = false;
			trails.push(trail);
			add(trail);

			var edge:FlxSprite = new FlxSprite(0, bar.y).makeGraphic(EDGE_W, barPx, Neon.CYAN);
			edge.scrollFactor.set();
			edge.alpha = 0.95;
			edge.visible = false;
			edges.push(edge);
			add(edge);

			// Orden mezclado (5 y 14 son coprimos): no se abren/cierran de arriba a abajo
			delays.push(((i * 5) % BAR_COUNT) / (BAR_COUNT - 1) * STAGGER);
		}

		buildPanel();

		// Scanline que baja durante toda la transición
		scanLine = new FlxSprite(0, -4).makeGraphic(width, 2, 0xFFFFFFFF);
		scanLine.scrollFactor.set();
		scanLine.alpha = 0.25;
		add(scanLine);

		super.create();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		time += elapsed;

		var t:Float = Math.min(1, time / duration); // 0 → 1
		var span:Float = 1 - STAGGER;

		for (i in 0...BAR_COUNT)
		{
			var p:Float = FlxMath.bound((t - delays[i]) / span, 0, 1);
			var dir:Int = (i % 2 == 0) ? 1 : -1;
			var bar:FlxSprite = bars[i];
			var edge:FlxSprite = edges[i];
			var trail:FlxSprite = trails[i];
			var edgeX:Float;

			if (!isTransIn)
			{
				// CUBRIR: la barra entra desde su lado; el borde brillante va delante
				bar.x = (1 - FlxEase.quartOut(p)) * (-dir * width);
				edgeX = (dir > 0) ? bar.x + width - EDGE_W : bar.x;
				trail.x = (dir > 0) ? edgeX - EDGE_W - 5 : edgeX + EDGE_W + 5;
			}
			else
			{
				// DESCUBRIR: la barra sale; el borde brillante marca el límite de lo descubierto
				bar.x = FlxEase.quartIn(p) * (dir * width);
				edgeX = (dir > 0) ? bar.x : bar.x + width - EDGE_W;
				trail.x = (dir > 0) ? edgeX + EDGE_W + 5 : edgeX - EDGE_W - 5;
			}

			edge.x = edgeX;
			edge.visible = trail.visible = (p > 0 && p < 1);
		}

		updatePanel(t, elapsed);

		scanLine.y = FlxMath.lerp(-4, height + 4, t);

		if (t >= 1 && !closing)
		{
			closing = true;

			if (!isTransIn && finishCallback != null)
			{
				// CUBRIR terminado: NO se cierra la transición. Se deja la pantalla tapada y
				// solo se avisa para cambiar de state. Flixel destruye este substate y su
				// cámara al ejecutar el cambio, así que el menú anterior nunca se ve entre
				// medio (ni durante la carga del nuevo state).
				var cb:Void->Void = finishCallback;
				finishCallback = null;
				cb();
			}
			else close();
		}
	}

	function updatePanel(t:Float, elapsed:Float):Void
	{
		// Aparece al terminar de cubrir; al descubrir se queda un momento y se desvanece
		var hudAlpha:Float = isTransIn
			? 1 - FlxMath.bound((t - 0.25) / 0.3, 0, 1)
			: FlxMath.bound((t - 0.35) / 0.3, 0, 1);
		for (i in 0...hud.length)
			hud[i].alpha = hudAlpha * hudBase[i];

		// Latido del logo + glitch cromático
		if (logo != null)
		{
			if (hudAlpha > 0 && time - lastBump >= 0.5)
			{
				lastBump = time;
				bumpScale = 1.06;
				if (!logoStatic)
				{
					logo.animation.play('bump', true);
					ghostM.animation.play('bump', true);
					ghostC.animation.play('bump', true);
				}
			}
			bumpScale = FlxMath.lerp(1, bumpScale, Math.exp(-elapsed * 9));
			if (logoStatic)
			{
				var sc:Float = logoBase * bumpScale;
				logo.scale.set(sc, sc);
				ghostM.scale.set(sc, sc);
				ghostC.scale.set(sc, sc);
			}
			var jitter:Float = FlxG.random.bool(6) ? FlxG.random.float(-8, 8) : 0;
			logo.x = logoX;
			ghostM.x = logoX + 4 + jitter;
			ghostC.x = logoX - 4 - jitter;
		}

		// Patrón de cuadros que se desplaza en diagonal
		if (checker != null)
		{
			checker.x = -((time * 40) % checkW);
			checker.y = -((time * 40) % checkH);
		}

		// Icono con pulso suave
		if (icon != null)
			icon.alpha = hudAlpha * (0.75 + 0.25 * Math.sin(time * 6));

		// Barra de progreso
		var prog:Float = isTransIn ? 1 : FlxMath.bound((t - 0.3) / 0.65, 0, 1);
		fill.scale.x = Math.max(1, PANEL_W * prog);
		fill.updateHitbox();
		fill.x = panelX;
		fill.y = TRACK_Y;

		// Texto de estado con puntos animados
		var dots:Int = Std.int(time * 4) % 4;
		if (dots != lastDots)
		{
			lastDots = dots;
			statusText.text = "CARGANDO" + ["", ".", "..", "..."][dots];
		}

		// Tip con efecto máquina de escribir
		var len:Int = currentTip.length;
		var chars:Int = isTransIn ? len : Std.int(len * FlxMath.bound((t - 0.4) / 0.5, 0, 1));
		if (chars != lastChars)
		{
			lastChars = chars;
			tipText.text = currentTip.substr(0, chars);
		}
	}

	override function close():Void
	{
		super.close();

		if (finishCallback != null)
		{
			finishCallback();
			finishCallback = null;
		}

		if (transCam != null && FlxG.cameras.list.contains(transCam))
			FlxG.cameras.remove(transCam, true);
		transCam = null;
	}
}
