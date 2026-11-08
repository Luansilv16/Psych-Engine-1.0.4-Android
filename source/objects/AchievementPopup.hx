package objects;

#if ACHIEVEMENTS_ALLOWED
import openfl.events.Event;
import openfl.geom.Matrix;
import flash.display.BitmapData;
import openfl.Lib;

class AchievementPopup extends openfl.display.Sprite {
	public var onFinish:Void->Void = null;
	var alphaTween:FlxTween;
	var lastScale:Float = 1;

	// --- Diseño futurista NixerEngine ---
	static inline var PW:Float = 440;   // ancho del panel
	static inline var PH:Float = 130;   // alto (no cambiar: el apilado usa 150 de separación)
	static inline var SLANT:Float = 24; // inclinación del borde derecho
	static inline var NEON:Int = 0x00E5FF;
	var neon:openfl.display.Sprite;   // borde que respira
	var sweep:openfl.display.Sprite;  // haz de luz que cruza el panel al aparecer
	var sweepTime:Float = 0;
	public function new(achieve:String, onFinish:Void->Void)
	{
		super();

		// fondo oscuro con el borde derecho inclinado
		graphics.beginFill(0x05060F, 0.92);
		graphics.moveTo(0, 0);
		graphics.lineTo(PW, 0);
		graphics.lineTo(PW - SLANT, PH);
		graphics.lineTo(0, PH);
		graphics.lineTo(0, 0);
		graphics.endFill();

		// barra de acento a la izquierda
		graphics.beginFill(NEON, 1);
		graphics.drawRect(0, 0, 5, PH);
		graphics.endFill();

		// borde neón (se anima en update)
		neon = new openfl.display.Sprite();
		neon.graphics.lineStyle(2, NEON, 1);
		neon.graphics.moveTo(0, 0);
		neon.graphics.lineTo(PW, 0);
		neon.graphics.lineTo(PW - SLANT, PH);
		neon.graphics.lineTo(0, PH);
		neon.graphics.lineTo(0, 0);
		addChild(neon);

		// achievement icon
		var graphic = null;
		var hasAntialias:Bool = ClientPrefs.data.antialiasing;
		var image:String = 'achievements/$achieve';
		
		var achievement:Achievement = null;
		if(Achievements.exists(achieve)) achievement = Achievements.get(achieve);

		#if MODS_ALLOWED
		var lastMod = Mods.currentModDirectory;
		if(achievement != null) Mods.currentModDirectory = achievement.mod != null ? achievement.mod : '';
		#end

		if(Paths.fileExists('images/$image-pixel.png', IMAGE))
		{
			graphic = Paths.image('$image-pixel', false);
			hasAntialias = false;
		}
		else graphic = Paths.image(image, false);

		#if MODS_ALLOWED
		Mods.currentModDirectory = lastMod;
		#end

		if(graphic == null) graphic = Paths.image('unknownMod', false);

		var sizeX = 100;
		var sizeY = 100;

		var imgX = 20;
		var imgY = 15;
		var image = graphic.bitmap;

		// marco neón del icono
		graphics.lineStyle(2, NEON, 0.9);
		graphics.drawRect(imgX - 3, imgY - 3, sizeX + 6, sizeY + 6);
		graphics.lineStyle();

		graphics.beginBitmapFill(image, new Matrix(sizeX / image.width, 0, 0, sizeY / image.height, imgX, imgY), false, hasAntialias);
		graphics.drawRect(imgX, imgY, sizeX, sizeY);

		// achievement name/description
		var name:String = 'Unknown';
		var desc:String = 'Description not found';
		if(achievement != null)
		{
			if(achievement.name != null) name = Language.getPhrase('achievement_$achieve', achievement.name);
			if(achievement.description != null)  desc = Language.getPhrase('description_$achieve', achievement.description);
		}

		var textX = sizeX + imgX + 18;
		var textY = imgY - 2;

		var text:FlxText = new FlxText(0, 0, 270, 'TEST!!!', 16);
		text.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT);
		drawTextAt(text, Language.getPhrase('achievement_unlocked_title', 'ACHIEVEMENT UNLOCKED'), textX, textY, 12, NEON);
		drawTextAt(text, name, textX, textY + 20, 20, 0xFFFFFF);
		drawTextAt(text, desc, textX, textY + 50, 14, 0xC8CCDC);
		graphics.endFill();

		text.graphic.bitmap.dispose();
		text.graphic.bitmap.disposeImage();
		text.destroy();

		// haz de luz que cruza el panel (se mueve en update)
		sweep = new openfl.display.Sprite();
		sweep.graphics.beginFill(NEON, 0.35);
		sweep.graphics.moveTo(14, 0);
		sweep.graphics.lineTo(46, 0);
		sweep.graphics.lineTo(32, PH);
		sweep.graphics.lineTo(0, PH);
		sweep.graphics.lineTo(14, 0);
		sweep.graphics.endFill();
		sweep.x = -50;
		addChild(sweep);

		// other stuff
		FlxG.stage.addEventListener(Event.RESIZE, onResize);
		addEventListener(Event.ENTER_FRAME, update);

		FlxG.game.addChild(this); //Don't add it below mouse, or it will disappear once the game changes states

		// fix scale
		lastScale = (FlxG.stage.stageHeight / FlxG.height);
		this.x = 30 * lastScale;
		this.y = -130 * lastScale;
		this.scaleX = lastScale;
		this.scaleY = lastScale;
		intendedY = 20;
	}

	var bitmaps:Array<BitmapData> = [];
	function drawTextAt(text:FlxText, str:String, textX:Float, textY:Float, size:Int = 16, color:Int = 0xFFFFFF)
	{
		text.size = size;
		text.color = color;
		text.text = str;
		text.updateHitbox();

		var clonedBitmap:BitmapData = text.graphic.bitmap.clone();
		bitmaps.push(clonedBitmap);
		graphics.beginBitmapFill(clonedBitmap, new Matrix(1, 0, 0, 1, textX, textY), false, false);
		graphics.drawRect(textX, textY, text.width, text.height);
	}
	
	var lerpTime:Float = 0;
	var countedTime:Float = 0;
	var timePassed:Float = -1;
	public var intendedY:Float = 0;

	function update(e:Event)
	{
		if(timePassed < 0) 
		{
			timePassed = Lib.getTimer();
			return;
		}

		var time = Lib.getTimer();
		var elapsed:Float = (time - timePassed) / 1000;
		timePassed = time;
		//trace('update called! $elapsed');

		if(elapsed >= 0.5) return; //most likely passed through a loading

		countedTime += elapsed;

		// borde neón que "respira"
		if(neon != null) neon.alpha = 0.7 + 0.3 * Math.sin(countedTime * 6);

		// haz de luz que cruza el panel una sola vez al aparecer
		if(sweep != null)
		{
			sweepTime += elapsed;
			var p:Float = sweepTime / 0.7;
			if(p < 1)
			{
				sweep.x = -50 + (PW + 20) * p;
				sweep.alpha = 1 - p; // se desvanece antes de salirse del panel
			}
			else
			{
				removeChild(sweep);
				sweep = null;
			}
		}
		if(countedTime < 3)
		{
			lerpTime = Math.min(1, lerpTime + elapsed);
			y = ((FlxEase.elasticOut(lerpTime) * (intendedY + 130)) - 130) * lastScale;
		}
		else
		{
			y -= FlxG.height * 2 * elapsed * lastScale;
			if(y <= -130 * lastScale)
				destroy();
		}
	}

	private function onResize(e:Event)
	{
		var mult = (FlxG.stage.stageHeight / FlxG.height);
		scaleX = mult;
		scaleY = mult;

		x = (mult / lastScale) * x;
		y = (mult / lastScale) * y;
		lastScale = mult;
	}

	public function destroy()
	{
		Achievements._popups.remove(this);
		//trace('destroyed achievement, new count: ' + Achievements._popups.length);

		if (FlxG.game.contains(this))
		{
			FlxG.game.removeChild(this);
		}
		FlxG.stage.removeEventListener(Event.RESIZE, onResize);
		removeEventListener(Event.ENTER_FRAME, update);
		deleteClonedBitmaps();
	}

	function deleteClonedBitmaps()
	{
		for (clonedBitmap in bitmaps)
		{
			if(clonedBitmap != null)
			{
				clonedBitmap.dispose();
				clonedBitmap.disposeImage();
			}
		}
		bitmaps = null;
	}
}
#end
