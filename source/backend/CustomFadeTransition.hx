package backend;

import flixel.util.FlxGradient;
import flixel.FlxSubState;
import flixel.FlxCamera;
import mobile.backend.MobileScaleMode;

class CustomFadeTransition extends FlxSubState {
	public static var finishCallback:Void->Void;
	var isTransIn:Bool = false;
	var transBlack:FlxSprite;
	var transGradient:FlxSprite;
	var transCam:FlxCamera;

	var duration:Float;
	public function new(duration:Float, isTransIn:Bool)
	{
		this.duration = duration;
		this.isTransIn = isTransIn;
		super();
	}

	override function create()
	{
		// Cámara propia, tan ancha como toda la pantalla (así la transición no deja bordes)
		var width:Int = FlxG.width + Std.int(MobileScaleMode.gameCutoutSize.x) * 2;
		var height:Int = FlxG.height;
		transCam = new FlxCamera(0, 0, width, height);
		transCam.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.add(transCam, false);
		cameras = [transCam];
		transGradient = FlxGradient.createGradientFlxSprite(1, height, (isTransIn ? [0x0, FlxColor.BLACK] : [FlxColor.BLACK, 0x0]));
		transGradient.scale.x = width;
		transGradient.updateHitbox();
		transGradient.scrollFactor.set();
		transGradient.x = 0;
		add(transGradient);

		transBlack = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		transBlack.scale.set(width, height + 400);
		transBlack.updateHitbox();
		transBlack.scrollFactor.set();
		transBlack.x = 0;
		add(transBlack);

		if(isTransIn)
			transGradient.y = transBlack.y - transBlack.height;
		else
			transGradient.y = -transGradient.height;

		super.create();
	}

	override function update(elapsed:Float) {
		super.update(elapsed);

		final height:Float = FlxG.height * Math.max(camera.zoom, 0.001);
		final targetPos:Float = transGradient.height + 50 * Math.max(camera.zoom, 0.001);
		if(duration > 0)
			transGradient.y += (height + targetPos) * elapsed / duration;
		else
			transGradient.y = (targetPos) * elapsed;

		if(isTransIn)
			transBlack.y = transGradient.y + transGradient.height;
		else
			transBlack.y = transGradient.y - transBlack.height;

		if(transGradient.y >= targetPos)
		{
			close();
		}
	}

	// Don't delete this
	override function close():Void
	{
		super.close();

		if(finishCallback != null)
		{
			finishCallback();
			finishCallback = null;
		}

		if (transCam != null && FlxG.cameras.list.contains(transCam))
			FlxG.cameras.remove(transCam, true);
		transCam = null;
	}
}
