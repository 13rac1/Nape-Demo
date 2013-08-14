package;

import openfl.Assets;
import flash.display.Bitmap;
import flash.display.BitmapData;
import openfl.display.FPS;
import flash.display.Graphics;
import flash.display.Sprite;
import flash.display.StageAlign;
import flash.display.StageScaleMode;
import openfl.display.Tilesheet;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.geom.Rectangle;
import flash.Lib;
import flash.sensors.Accelerometer;
import flash.events.AccelerometerEvent;

import nape.geom.Vec2;
import nape.phys.Body;
import nape.phys.BodyType;
import nape.shape.Polygon;
import nape.space.Space;
#if flash
	import nape.util.BitmapDebug;
#else
	import nape.util.ShapeDebug;
#end
import nape.util.Debug;


class Main extends Sprite {
	var space:Space;
	var debug:Debug;
  var accelX:Float;
  var accelY:Float;
  var accelZ:Float;

	// Storage of the flash logo bitmap
	public static var bitmapLogo:BitmapData;
	
	// Store the last time, for time difference calculations
	public var lastTime:Int;
	
	// Physics scaling, adjust to mimic gravity
	static public inline var PHYSICS_SCALE:Float = 800;
	// Size of the boxes
	public static inline var BOX_SIZE:Int = 20;
	
	// The image tilesheet
	var tilesheet:Tilesheet;
	// The tilesheet drawlist, what to draw
	var drawList:Array<Float>;

	/**
	 * Event.ADDED_TO_STAGE listener, insantiaites remainder of program.
	 * @param	event
	 */
	private function construct (event:Event) {
		// Remove self as a listener.
		removeEventListener(Event.ADDED_TO_STAGE, construct);

		Lib.trace("construct() called");
		// Setup stage.
		stage.align = StageAlign.TOP_LEFT;
		stage.scaleMode = StageScaleMode.NO_SCALE;
		
		// Create the world with gravity
		var gravity = Vec2.weak(0, 700);
		space = new Space(gravity);

		var w = stage.stageWidth;
		var h = stage.stageHeight;

		// Create a new BitmapDebug screen matching stage dimensions.
		#if flash
			debug = new BitmapDebug(w, h, 0x333333, true);
		#else
			debug = new ShapeDebug(w, h);
		#end
		addChild(debug.display);

		// Create world bounds.
		var walls = new Body(BodyType.STATIC);
		walls.shapes.add(new Polygon(Polygon.rect(0, 0, w, 10)));
		walls.shapes.add(new Polygon(Polygon.rect(0, 0, 10, h)));
		walls.shapes.add(new Polygon(Polygon.rect(0, h - 10, w, 10)));
		walls.shapes.add(new Polygon(Polygon.rect(w - 10, 0, 10, h)));
		walls.space = space;

		// Init drawList for drawTiles
		drawList = new Array<Float>();
		// Load logo bitmap image
		bitmapLogo = Assets.getBitmapData("assets/nme.png");
		// Create a new Tilesheet using the bitmap logo data
		tilesheet = new Tilesheet(bitmapLogo);
		// Create a rectangle specifying the bitmap on the tilesheet (normally there is more than one image per tilesheet.
		var rect = new Rectangle (0, 0, bitmapLogo.width, bitmapLogo.height);
		// Add the Rectangle as the first Tile
		tilesheet.addTileRect(rect);
		
		// Create the initial 30 on-screen boxes.
		for (i in 0...30) {
			createBox(100, 100, BOX_SIZE, BOX_SIZE);
		}
				
		// Add FPS display
		var f = new FPS();
		f.textColor = 0xFFFFFF;
		f.y = -3;
		f.x = 20;
		addChild(f);
		// Init the last time value
		lastTime = Lib.getTimer();

		// Add Event listeners
		stage.addEventListener(MouseEvent.CLICK, stage_onClick);
		//stage.addEventListener(Event.RESIZE, stage_onResize);
		stage.addEventListener(Event.ENTER_FRAME, update);
    if (Accelerometer.isSupported) {
      var accl:Accelerometer = new Accelerometer();
      accl.addEventListener(AccelerometerEvent.UPDATE, onAcclUpdate);
    }
	}

  /**
   * Update the current stored Accelerometer data
   * @param event
   */
  function onAcclUpdate(event:AccelerometerEvent):Void {
    accelX = event.accelerationX;
    accelY = event.accelerationY;
    accelZ = event.accelerationZ;
  }

	/**
	 * Create a dynamic/static rectangle Shape in a Body
	 * @param	x
	 * @param	y
	 * @param	width
	 * @param	height
	 * @return	The created Body
	 */
	private function createBox (x:Float, y:Float, width:Float, height:Float):Body {
		// Create a new nape Body
		var box = new Body(BodyType.DYNAMIC);
		// Create a new Polygon, without shape the body is nothing.
		box.shapes.add(new Polygon(Polygon.box(width, height)));
		box.position.setxy(x, y);
		// Add the shape to the space.
		box.space = space;
		return box;
	}
	
	/**
	 * The onEnterFrame update function
	 *
	 * Updates physics, gravity via accelerometer data, and redraws the world.
	 * @param	event
	 */
	private function update(event:Event) {
		// Get the current timestamp
		var nowTime:Int = Lib.getTimer();
		// Get the time change since update() was last called, as seconds
		var dTime:Float = (nowTime - lastTime) / 1000;
		// Store the new last time
		lastTime = nowTime;

		// If not Flash, attempt to use Accelerometer data
		#if !flash

		if (Accelerometer.isSupported) {
			var ax = PHYSICS_SCALE * -accelX;
		  var ay = PHYSICS_SCALE * accelY;
			//var az = acc.z;
			// Set gravity vector
			var gravity = Vec2.weak(ax, ay);
			space.gravity = gravity;
		}
		#end
		
		// Step forward in simulation by the required number of seconds.
		space.step(1 / stage.frameRate);
		//space.step(dTime);
		// Render Space to the debug draw. (Note: Transparent only for Flash)
		//debug.clear();
		//debug.draw(space);
		//debug.flush();
		
		// Create the drawList for drawTiles
		var i = 0;
		var box_sqrt = BOX_SIZE / Math.sqrt(2);
		for (c in space.bodies) {
			if (c.isDynamic()) {
				drawList[i++] = c.position.x - Math.cos(c.rotation+Math.PI/4) * box_sqrt;
				drawList[i++] = c.position.y - Math.sin(c.rotation+Math.PI/4) * box_sqrt;
				drawList[i++] = 0;
				drawList[i++] = 0.15;
				drawList[i++] = c.rotation;
			}
		}
		// Clear the current display
		this.graphics.clear();
    // Draw the tiles.
		tilesheet.drawTiles(this.graphics, drawList, false, Tilesheet.TILE_SCALE | Tilesheet.TILE_ROTATION);
	}
	
	/**
	 * Stage onClick listener, creates new boxes on click.
	 * @param	event
	 */
	private function stage_onClick(event:MouseEvent):Void {
		var range = PHYSICS_SCALE * 3;
		var delta = range / 2;
		for (i in 0...4) {
			// Create a new box at the mouse x/y
			var b = createBox(event.stageX, event.stageY, BOX_SIZE, BOX_SIZE);
			// Set a random speed/direction based on PHYSICS_SCALE
			b.velocity = Vec2.weak(Math.random() * range - delta, Math.random() * range - delta);
		}
	}
	
	/**
	 * Program execution entry function
	 */
	public static function main () {
		Lib.trace("Main() called");
		// Add Main() class to the stage.
		Lib.current.addChild (new Main ());
	}

	/**
	 * Main class constructor function
	 */
	public function new () {
		super ();
		// Add a listener to wait for the stage to be available.
		addEventListener (Event.ADDED_TO_STAGE, construct);
	}
}
