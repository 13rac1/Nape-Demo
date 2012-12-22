package;

import nme.Assets;
import nme.display.Bitmap;
import nme.display.BitmapData;
import nme.display.FPS;
import nme.display.Graphics;
import nme.display.Sprite;
import nme.display.StageAlign;
import nme.display.StageScaleMode;
import nme.display.Tilesheet;
import nme.events.Event;
import nme.events.MouseEvent;
import nme.geom.Rectangle;
import nme.Lib;
import nme.ui.Accelerometer;
import phx.Body;
import phx.col.AABB;
import phx.col.SortedList;
import phx.Polygon;
import phx.Shape;
import phx.Vector;
import phx.World;


class Main extends Sprite {
	// Storage of the NME logo bitmap
	public static var bitmapLogo:BitmapData;

	// StageWidth
	public static var sw:Int;
	// StageHeight
	public static var sh:Int;
	
	// Store the last time, for time difference calculations
	public var lastTime:Int;
	
	// Physics scaling, adjust to mimic gravity
	static public inline var PHYSICS_SCALE:Float = 100;
	// Size of the boxes
	public static inline var BOX_SIZE:Int = 20;
	
	// The image tilesheet
	var tilesheet:Tilesheet;
	// The tilesheet drawlist, what to draw
	var drawList:Array<Float>;
	// The physaxe world
	private var world:World;

	private function construct () {
		Lib.trace("construct() called");
		// Setup stage.
		stage.align = StageAlign.TOP_LEFT;
		stage.scaleMode = StageScaleMode.NO_SCALE;
		
		// Store stage height/width
		resize ();
		
		// Create a new bounding box to limit the world
		var size = new AABB( -1000, -1000, 1000, 1000);
		// Create a sorted list to store the bodies.
		var bf = new SortedList();
		// Create the world
		world = new World(size, bf);
		// Apply gravity.
		world.gravity = new Vector(0, PHYSICS_SCALE);
		//world.sleepEpsilon = 0;
			
		// Create world bounds.
		createBox(-20, 0, 40, sh, false);
		createBox(sw - 20, 0, 40, sh, false);
		createBox(0, -20, sw, 40, false);
		createBox(0, sh-20, sw, 40, false);
		
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
		
		// Create the initial 40 on-screen boxes.
		for (i in 0...40) {
			createBox(Math.random() * stage.stageWidth, Math.random() * stage.stageHeight, BOX_SIZE, BOX_SIZE, true);
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
		stage.addEventListener(Event.RESIZE, stage_onResize);
		stage.addEventListener(Event.ENTER_FRAME, update);
	}
	
	/**
	 * Create a dynamic/static rectangle Shape in a Body
	 * @param	x
	 * @param	y
	 * @param	width
	 * @param	height
	 * @param	dynamicBody
	 * @return	The created Body or null
	 */
	private function createBox (x:Float, y:Float, width:Float, height:Float, dynamicBody:Bool):Body {
		if (dynamicBody) {
			// Create a new phyaxe Body
			var b:Body = new Body(x, y);
			// Create a new physaxe Shape, without a shape the body is nothing.
			var shape:Shape = Shape.makeBox(width, height);
			// Specify the friction coefficient of the shape
			shape.material.friction = 0.1;
			// Add the shape to the Body.
			b.addShape(shape);

			// Circle test.
			//b.addShape(new phx.Circle(width/2, new Vector(0,0)));
			// Update physics after changing the Body's Shape.
			b.updatePhysics();
			// Add the Body to the World
			world.addBody(b);
			return b;
		}
		else {
			// Create a Static non-moving shape.
			world.addStaticShape(Shape.makeBox(width, height, x, y));
			return null;
		}
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
		var acc = Accelerometer.get();
		if (acc != null) {
			var ax = PHYSICS_SCALE * acc.x;
			var ay = PHYSICS_SCALE * -acc.y;
			//var az = acc.z;
			// Set gravity vector
			world.gravity.set(ax, ay);
		}
		#end
		
		// Update world physics, time X 4 to better simulate earth gravity
		world.step(dTime * 4, 20);
		
		// The Physaxe debug world drawing
        //var g = nme.Lib.current.graphics;
        //g.clear();
        //var fd = new phx.FlashDraw(g);
        //fd.drawCircleRotation = true;
        //fd.drawWorld(world);
		
		// Create the drawList for drawTiles
		var i = 0;
		var box_sqrt = BOX_SIZE / Math.sqrt(2);
		for (c in world.bodies) {
			drawList[i++] = c.x - Math.cos(c.a+Math.PI/4) * box_sqrt;
			drawList[i++] = c.y - Math.sin(c.a+Math.PI/4) * box_sqrt;
			drawList[i++] = 0;
			drawList[i++] = 0.15;
			drawList[i++] = -c.a;
		}
		// Clear the current display
		this.graphics.clear();
		// Draw the tiles. http://code.google.com/p/nekonme/source/browse/trunk/nme/display/Tilesheet.hx?r=1600
		tilesheet.drawTiles(this.graphics, drawList, false, Tilesheet.TILE_SCALE | Tilesheet.TILE_ROTATION);
	}
	
	/**
	 * Stage onClick listener, creates new boxes on click.
	 * @param	event
	 */
	private function stage_onClick(event:MouseEvent):Void {
		var range = PHYSICS_SCALE * 3;
		var delta = range / 2;
		for (i in 0...10) {
			// Create a new box at the mouse x/y
			var b = createBox(event.stageX, event.stageY, BOX_SIZE, BOX_SIZE, true);
			// Set a random speed/direction based on PHYSICS_SCALE
			b.setSpeed(Math.random() * range - delta, Math.random() * range - delta);
		}
	}
	
	
	/**
	 * Stage onResize event listener
	 * @param	event
	 */
	private function stage_onResize (event:Event):Void {
		// @todo: Actually resize the content.
		resize();
	}

	/**
	 * Called by resize listener, stores stage info.
	 */
	private function resize () {
		// @todo remove?
		sw = stage.stageWidth;
		sh = stage.stageHeight;
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
		addEventListener (Event.ADDED_TO_STAGE, this_onAddedToStage);
	}
	
	/**
	 * Event.ADDED_TO_STAGE listener, insantiaites remainder of program.
	 * @param	event
	 */
	private function this_onAddedToStage (event:Event):Void {
		// Remove self as a listener.
		removeEventListener(Event.ADDED_TO_STAGE, this_onAddedToStage);
		// Call program constructor, which expects existing stage.
		construct();
	}
}
