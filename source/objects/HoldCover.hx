package objects;

import shaders.RGBPalette;

/**
 * V-Slice hold cover (splash que se queda mientras mantienes una nota larga).
 * Usa el RGB de la strum, asi que respeta los colores de Colors Settings.
 * Assets: images/holdCover/hcrgb.(png|xml) y hcrgbp.(png|xml) para pixel.
 */
class HoldCover extends FlxSprite
{
	public var strum:StrumNote;
	public var isPlayer:Bool = false;

	var rgb:RGBPalette;
	var offX:Float = -105;
	var offY:Float = -100;

	public static function getPath():String
		return PlayState.isPixelStage ? 'holdCover/hcrgbp' : 'holdCover/hcrgb';

	public static function assetsExist():Bool
		return Paths.fileExists('images/' + getPath() + '.png', IMAGE);

	public function new(strum:StrumNote, isPlayer:Bool)
	{
		super();
		this.strum = strum;
		this.isPlayer = isPlayer;
		moves = false;

		var pixel:Bool = PlayState.isPixelStage;
		frames = Paths.getSparrowAtlas(getPath());

		var fps:Int = pixel ? 33 : 24;
		animation.addByPrefix('hold', 'lop', fps, true);
		animation.addByPrefix('end', 'bai', fps, false);
		animation.play('hold');

		if (pixel)
		{
			scale.set(6, 6);
			updateHitbox();
			antialiasing = false;
			offX = -385;
			offY = -125;
		}
		else antialiasing = ClientPrefs.data.antialiasing;

		rgb = new RGBPalette();
		shader = rgb.shader;
		syncColors();

		visible = false;
	}

	/** Se llama por cada pieza de sustain golpeada. */
	public function hit(isEnd:Bool):Void
	{
		if (!ClientPrefs.data.holdSplash) return;

		if (isPlayer)
		{
			visible = true;
			animation.play(isEnd ? 'end' : 'hold');
		}
		else
		{
			visible = !isEnd; // el oponente no hace animacion de fin
			animation.play('hold');
		}
	}

	public function hide():Void
	{
		visible = false;
		animation.play('hold');
	}

	function syncColors():Void
	{
		if (strum == null || strum.rgbShader == null) return;
		if (rgb.r != strum.rgbShader.r) rgb.r = strum.rgbShader.r;
		if (rgb.g != strum.rgbShader.g) rgb.g = strum.rgbShader.g;
		if (rgb.b != strum.rgbShader.b) rgb.b = strum.rgbShader.b;
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (strum == null) return;

		setPosition(strum.x + offX, strum.y + offY);
		alpha = strum.alpha;
		if (visible) syncColors();

		var cur = animation.curAnim;
		if (isPlayer && cur != null && cur.name == 'end' && cur.finished)
			hide();
	}
}
