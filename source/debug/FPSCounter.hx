package debug;

import flixel.FlxG;
import openfl.Lib;
import haxe.Timer;
import openfl.display.Sprite;
import openfl.text.TextField;
import openfl.text.TextFieldAutoSize;
import openfl.text.TextFormat;
import openfl.system.System as OpenFlSystem;
import lime.system.System as LimeSystem;

/**
	Contador de FPS estilo futurista de NixerEngine:
	panel oscuro con borde inclinado, número grande, memoria y una barra de uso.
	El color neón cambia con el rendimiento (cian / amarillo / rojo).
**/
#if cpp
#if windows
@:cppFileCode('#include <windows.h>')
#elseif (ios || mac)
@:cppFileCode('#include <mach-o/arch.h>')
#else
@:headerInclude('sys/utsname.h')
#end
#end
class FPSCounter extends Sprite
{
	/** true = en la esquina superior derecha, false = superior izquierda */
	public static var alignRight:Bool = true;

	static inline var PANEL_W:Float = 176;
	static inline var SLANT:Float = 18;

	/**
		The current frame rate, expressed using frames-per-second
	**/
	public var currentFPS(default, null):Int;

	/**
		The current memory usage in bytes (WARNING: this is NOT your total program memory usage, rather it shows the garbage collector memory)
	**/
	public var memoryMegas(get, never):Float;

	@:noCompletion private var times:Array<Float>;
	@:noCompletion private var lastFramerateUpdateTime:Float;
	@:noCompletion private var updateTime:Int;
	@:noCompletion private var framesCount:Int;
	@:noCompletion private var prevTime:Int;

	public var os:String = '';
	public var textColor:Int = 0xFFFFFFFF;

	var fpsNum:TextField;
	var fpsLabel:TextField;
	var memText:TextField;
	var osText:TextField;

	public function new(x:Float = 10, y:Float = 10, color:Int = 0x000000)
	{
		super();

		#if !officialBuild
		if (LimeSystem.platformName == LimeSystem.platformVersion || LimeSystem.platformVersion == null)
			os = '\nOS: ${LimeSystem.platformName}' #if cpp + ' ${getArch() != 'Unknown' ? getArch() : ''}' #end;
		else
			os = '\nOS: ${LimeSystem.platformName}' #if cpp + ' ${getArch() != 'Unknown' ? getArch() : ''}' #end + ' - ${LimeSystem.platformVersion}';
		#end

		mouseEnabled = false;
		mouseChildren = false;

		fpsNum = makeText(28, true, 0xFFFFFF);
		fpsLabel = makeText(12, true, 0x00E5FF);
		memText = makeText(12, false, 0xDDDDDD);
		osText = makeText(10, false, 0x9AA0B4);
		addChild(fpsNum);
		addChild(fpsLabel);
		addChild(memText);
		addChild(osText);

		currentFPS = 0;
		times = [];
		lastFramerateUpdateTime = Timer.stamp();
		prevTime = Lib.getTimer();
		updateTime = prevTime + 500;

		updateText();
		positionFPS(x, y);
	}

	function makeText(size:Int, bold:Bool, color:Int):TextField
	{
		var t:TextField = new TextField();
		t.selectable = false;
		t.mouseEnabled = false;
		t.multiline = false;
		t.autoSize = TextFieldAutoSize.LEFT;
		t.defaultTextFormat = new TextFormat("_sans", size, color, bold);
		t.text = '';
		return t;
	}

	public dynamic function updateText():Void // so people can override it in hscript
	{
		var maxFps:Float = (FlxG.stage != null && FlxG.stage.window != null) ? FlxG.stage.window.frameRate : 60;
		var ratio:Float = (maxFps > 0) ? currentFPS / maxFps : 1;
		var accent:Int = (ratio >= 0.85) ? 0x00E5FF : ((ratio >= 0.5) ? 0xFFD600 : 0xFF1744);
		textColor = 0xFF000000 | accent;

		var mem:Float = memoryMegas;
		fpsNum.text = Std.string(currentFPS);
		fpsLabel.text = 'FPS';
		fpsLabel.textColor = accent;
		memText.text = 'MEM ' + flixel.util.FlxStringUtil.formatBytes(mem);
		osText.text = (os != null) ? StringTools.trim(os) : '';

		drawPanel(accent, mem);
	}

	// Coloca los textos y dibuja el panel inclinado con borde neón y la barra de memoria
	function drawPanel(accent:Int, mem:Float):Void
	{
		var pad:Float = 10;
		var xs:Float = alignRight ? SLANT + pad - 4 : pad;

		fpsNum.x = xs;
		fpsNum.y = 0;
		fpsLabel.x = fpsNum.x + fpsNum.width + 2;
		fpsLabel.y = fpsNum.y + fpsNum.height - fpsLabel.height - 5;
		memText.x = xs;
		memText.y = fpsNum.y + fpsNum.height - 4;

		var barY:Float = memText.y + memText.height + 1;
		var h:Float = barY + 12;
		osText.visible = (osText.text != '');
		if (osText.visible)
		{
			osText.x = xs;
			osText.y = barY + 8;
			h = osText.y + osText.height + 4;
		}

		var g = graphics;
		g.clear();

		// Fondo oscuro semitransparente (borde inclinado)
		g.beginFill(0x05060F, 0.62);
		if (alignRight)
		{
			g.moveTo(0, 0);
			g.lineTo(PANEL_W, 0);
			g.lineTo(PANEL_W, h);
			g.lineTo(SLANT, h);
		}
		else
		{
			g.moveTo(0, 0);
			g.lineTo(PANEL_W, 0);
			g.lineTo(PANEL_W - SLANT, h);
			g.lineTo(0, h);
		}
		g.endFill();

		// Borde neón (diagonal + base)
		g.lineStyle(2, accent, 0.95);
		if (alignRight)
		{
			g.moveTo(0, 0);
			g.lineTo(SLANT, h);
			g.lineTo(PANEL_W, h);
		}
		else
		{
			g.moveTo(PANEL_W, 0);
			g.lineTo(PANEL_W - SLANT, h);
			g.lineTo(0, h);
		}
		g.lineStyle();

		// Barra de memoria (0 a 1 GB)
		var bw:Float = PANEL_W - SLANT - xs - 8;
		var fill:Float = Math.max(0, Math.min(1, mem / (1024 * 1024 * 1024)));
		g.beginFill(0xFFFFFF, 0.14);
		g.drawRect(xs, barY, bw, 4);
		g.endFill();
		g.beginFill(accent, 0.95);
		g.drawRect(xs, barY, bw * fill, 4);
		g.endFill();
	}

	var deltaTimeout:Float = 0.0;
	private override function __enterFrame(deltaTime:Float):Void
	{
		if (ClientPrefs.data.fpsRework)
		{
			// Flixel keeps reseting this to 60 on focus gained
			if (FlxG.stage.window.frameRate != ClientPrefs.data.framerate && FlxG.stage.window.frameRate != FlxG.game.focusLostFramerate)
				FlxG.stage.window.frameRate = ClientPrefs.data.framerate;

			var currentTime = openfl.Lib.getTimer();
			framesCount++;

			if (currentTime >= updateTime)
			{
				var elapsed = currentTime - prevTime;
				currentFPS = Math.ceil((framesCount * 1000) / elapsed);
				framesCount = 0;
				prevTime = currentTime;
				updateTime = currentTime + 500;
			}

			// Set Update and Draw framerate to the current FPS every 1.5 second to prevent "slowness" issue
			if ((FlxG.updateFramerate >= currentFPS + 5 || FlxG.updateFramerate <= currentFPS - 5)
				&& haxe.Timer.stamp() - lastFramerateUpdateTime >= 1.5
				&& currentFPS >= 30)
			{
				FlxG.updateFramerate = FlxG.drawFramerate = currentFPS;
				lastFramerateUpdateTime = haxe.Timer.stamp();
			}
		}
		else
		{
			final now:Float = haxe.Timer.stamp() * 1000;
			times.push(now);
			while (times[0] < now - 1000)
				times.shift();
			// prevents the overlay from updating every frame, why would you need to anyways @crowplexus
			if (deltaTimeout < 50)
			{
				deltaTimeout += deltaTime;
				return;
			}

			currentFPS = times.length < FlxG.updateFramerate ? times.length : FlxG.updateFramerate;
			deltaTimeout = 0.0;
		}

		updateText();
	}

	inline function get_memoryMegas():Float
		return cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_USAGE);

	public inline function positionFPS(X:Float, Y:Float, ?scale:Float = 1)
	{
		scaleX = scaleY = #if android (scale > 1 ? scale : 1) #else (scale < 1 ? scale : 1) #end;
		if (alignRight)
			x = FlxG.stage.stageWidth - FlxG.game.x - width - X; // pegado al borde derecho
		else
			x = FlxG.game.x + X;
		y = FlxG.game.y + Y;
	}

	#if cpp
	#if windows
	@:functionCode('
		SYSTEM_INFO osInfo;

		GetSystemInfo(&osInfo);

		switch(osInfo.wProcessorArchitecture)
		{
			case 9:
				return ::String("x86_64");
			case 5:
				return ::String("ARM");
			case 12:
				return ::String("ARM64");
			case 6:
				return ::String("IA-64");
			case 0:
				return ::String("x86");
			default:
				return ::String("Unknown");
		}
	')
	#elseif (ios || mac)
	@:functionCode('
		const NXArchInfo *archInfo = NXGetLocalArchInfo();
    	return ::String(archInfo == NULL ? "Unknown" : archInfo->name);
	')
	#else
	@:functionCode('
		struct utsname osInfo{};
		uname(&osInfo);
		return ::String(osInfo.machine);
	')
	#end
	@:noCompletion
	private function getArch():String
	{
		return "Unknown";
	}
	#end
}
