package backend;

import flixel.FlxSubState;
import flixel.FlxCamera;
import flixel.math.FlxMath;
import mobile.backend.MobileScaleMode;

/**
 * Transición futurista NixerEngine (persianas digitales)
 *
 * - transOut (isTransIn = false): 14 barras entran desde los lados, en orden mezclado,
 *   cada una con un borde cian/magenta, hasta tapar toda la pantalla.
 *   Al final aparece una línea central y el texto NIXERENGINE.
 * - transIn (isTransIn = true): empieza con todo tapado y las barras se abren
 *   de la misma forma, descubriendo el nuevo estado sin saltos.
 *
 * Compatible con Wide Screen Mode ON/OFF.
 */
class CustomFadeTransition extends FlxSubState {
	public static var finishCallback:Void->Void;

	var isTransIn:Bool = false;
	var duration:Float;

	var transCam:FlxCamera;
	var bars:Array<FlxSprite> = [];
	var edges:Array<FlxSprite> = [];
	var trails:Array<FlxSprite> = [];
	var delays:Array<Float> = [];
	var coreLine:FlxSprite;
	var scanLine:FlxSprite;
	var label:FlxText;

	var time:Float = 0;
	var closing:Bool = false;
	var width:Int = 1280;
	var height:Int = 720;

	// Colores futuristas
	static inline var ACCENT:Int = 0xFF00F0FF;   // cian
	static inline var ACCENT2:Int = 0xFFB000FF;  // magenta
	static inline var DARK:Int = 0xFF050510;

	static inline var BAR_COUNT:Int = 14;
	static inline var STAGGER:Float = 0.4;  // parte de la duración usada para escalonar las barras
	static inline var EDGE_W:Int = 4;

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

		var barH:Float = height / BAR_COUNT;
		var barPx:Int = Math.ceil(barH) + 1;

		for (i in 0...BAR_COUNT)
		{
			var dir:Int = (i % 2 == 0) ? 1 : -1;

			var bar:FlxSprite = new FlxSprite(0, Math.floor(i * barH)).makeGraphic(width, barPx, DARK);
			bar.scrollFactor.set();
			// Cubrir: arrancan fuera de pantalla. Descubrir: arrancan tapando todo.
			bar.x = isTransIn ? 0 : -dir * width;
			bars.push(bar);
			add(bar);

			var trail:FlxSprite = new FlxSprite(0, bar.y).makeGraphic(EDGE_W, barPx, ACCENT2);
			trail.scrollFactor.set();
			trail.alpha = 0.5;
			trail.visible = false;
			trails.push(trail);
			add(trail);

			var edge:FlxSprite = new FlxSprite(0, bar.y).makeGraphic(EDGE_W, barPx, ACCENT);
			edge.scrollFactor.set();
			edge.alpha = 0.95;
			edge.visible = false;
			edges.push(edge);
			add(edge);

			// Orden mezclado (5 y 14 son coprimos): no se abren/cierran de arriba a abajo
			delays.push(((i * 5) % BAR_COUNT) / (BAR_COUNT - 1) * STAGGER);
		}

		// Línea central + texto (se ven con la pantalla tapada)
		coreLine = new FlxSprite(0, height / 2 - 1).makeGraphic(width, 3, ACCENT);
		coreLine.scrollFactor.set();
		coreLine.scale.x = isTransIn ? 1 : 0;
		add(coreLine);

		label = new FlxText(0, height / 2 - 44, width, "NIXERENGINE", 22);
		label.setFormat(Paths.font('vcr.ttf'), 22, ACCENT, CENTER);
		label.scrollFactor.set();
		label.alpha = isTransIn ? 1 : 0;
		add(label);

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

		if (!isTransIn)
		{
			coreLine.scale.x = FlxEase.quartOut(FlxMath.bound((t - 0.55) / 0.45, 0, 1));
			label.alpha = FlxMath.bound((t - 0.75) / 0.25, 0, 1);
		}
		else
		{
			coreLine.scale.x = 1 - FlxEase.quartIn(FlxMath.bound(t / 0.35, 0, 1));
			label.alpha = 1 - FlxMath.bound(t / 0.25, 0, 1);
		}

		scanLine.y = FlxMath.lerp(-4, height + 4, t);

		if (t >= 1 && !closing)
		{
			closing = true;
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
