package backend;

import flixel.FlxSubState;
import flixel.FlxCamera;
import flixel.util.FlxSpriteUtil;
import flixel.math.FlxMath;
import mobile.backend.MobileScaleMode;

/**
 * Transición futurista NixerEngine
 * Compatible con Wide Screen Mode ON/OFF
 */
class CustomFadeTransition extends FlxSubState {
	public static var finishCallback:Void->Void;

	var isTransIn:Bool = false;
	var duration:Float;

	var transCam:FlxCamera;
	var bars:Array<FlxSprite> = [];
	var glowLine:FlxSprite;
	var scanLine:FlxSprite;
	var overlay:FlxSprite;

	var time:Float = 0;
	var width:Int = 1280;
	var height:Int = 720;

	// Colores futuristas
	static inline var ACCENT:Int = 0xFF00F0FF;   // cyan
	static inline var ACCENT2:Int = 0xFFB000FF;  // magenta
	static inline var DARK:Int = 0xFF050510;

	public function new(duration:Float, isTransIn:Bool)
	{
		this.duration = Math.max(0.01, duration);
		this.isTransIn = isTransIn;
		super();
	}

	override function create()
	{
		// Ancho real de pantalla (incluye cutouts / wide mode)
		width = FlxG.width + Std.int(MobileScaleMode.gameCutoutSize.x) * 2;
		height = FlxG.height;

		transCam = new FlxCamera(0, 0, width, height);
		transCam.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(transCam, false);
		cameras = [transCam];

		// Fondo oscuro base
		overlay = new FlxSprite().makeGraphic(width, height, DARK);
		overlay.scrollFactor.set();
		overlay.alpha = isTransIn ? 1 : 0;
		add(overlay);

		// Barras horizontales tipo "digital wipe"
		var barCount:Int = 12;
		var barH:Float = height / barCount;

		for (i in 0...barCount)
		{
			var bar = new FlxSprite().makeGraphic(width + 40, Std.int(barH) + 2, DARK);
			bar.scrollFactor.set();
			bar.y = i * barH;

			// Alternar dirección (izquierda / derecha) para look más dinámico
			if (isTransIn)
			{
				bar.x = (i % 2 == 0) ? -width - 60 : width + 60;
			}
			else
			{
				bar.x = 0;
			}
			bar.alpha = 1;
			bars.push(bar);
			add(bar);
		}

		// Línea de glow cyan que recorre la transición
		glowLine = new FlxSprite().makeGraphic(8, height, ACCENT);
		glowLine.scrollFactor.set();
		glowLine.alpha = 0.9;
		glowLine.x = isTransIn ? -20 : width + 10;
		add(glowLine);

		// Segunda línea magenta (detrás, más suave)
		var glow2 = new FlxSprite().makeGraphic(4, height, ACCENT2);
		glow2.scrollFactor.set();
		glow2.alpha = 0.55;
		glow2.x = glowLine.x - 18;
		glow2.ID = 99;
		add(glow2);
		bars.push(glow2); // reutilizamos array para destruir después

		// Scanline sutil
		scanLine = new FlxSprite().makeGraphic(width, 2, 0x55FFFFFF);
		scanLine.scrollFactor.set();
		scanLine.alpha = 0.25;
		scanLine.y = -10;
		add(scanLine);

		super.create();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		time += elapsed;

		var t:Float = Math.min(1, time / duration); // 0 → 1

		if (isTransIn)
		{
			// Entrada: las barras entran y el overlay se desvanece
			var ease = FlxEase.cubeOut(t);

			for (i in 0...bars.length)
			{
				var bar = bars[i];
				if (bar.ID == 99) // glow2
				{
					bar.x = FlxMath.lerp(width + 40, -30, ease) - 18;
					continue;
				}
				if (i >= 12) continue;

				var fromX = (i % 2 == 0) ? -width - 60 : width + 60;
				var toX = 0.0;
				// Stagger ligero
				var localT = FlxMath.bound((t - i * 0.018) / 0.75, 0, 1);
				var localEase = FlxEase.cubeOut(localT);
				bar.x = FlxMath.lerp(fromX, toX, localEase);
			}

			glowLine.x = FlxMath.lerp(width + 20, -30, ease);
			overlay.alpha = 1 - ease;

			// Scanline baja rápido
			scanLine.y = FlxMath.lerp(-10, height + 10, FlxEase.quadIn(t));
			scanLine.alpha = 0.35 * (1 - t);
		}
		else
		{
			// Salida: las barras salen hacia los lados y el overlay aparece
			var ease = FlxEase.cubeIn(t);

			for (i in 0...bars.length)
			{
				var bar = bars[i];
				if (bar.ID == 99)
				{
					bar.x = FlxMath.lerp(-30, width + 40, ease) - 18;
					continue;
				}
				if (i >= 12) continue;

				var toX = (i % 2 == 0) ? -width - 60 : width + 60;
				var localT = FlxMath.bound((t - i * 0.015) / 0.8, 0, 1);
				var localEase = FlxEase.cubeIn(localT);
				bar.x = FlxMath.lerp(0, toX, localEase);
			}

			glowLine.x = FlxMath.lerp(-20, width + 30, ease);
			overlay.alpha = ease;

			scanLine.y = FlxMath.lerp(-10, height + 10, FlxEase.quadOut(t));
			scanLine.alpha = 0.3 * t;
		}

		if (t >= 1)
		{
			close();
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
