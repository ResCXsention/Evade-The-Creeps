/*
	MIT Licence

	Copyright (c) 2022 ResCXention

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
*/

module modules.classes;

import std.stdio : writeln;
import std.math : sqrt, cos, sin, PI;
import std.conv : to;
import std.random : uniform;
import std.string : toStringz;
import bindbc.sdl;
import bindbc.sdl.image;
import bindbc.sdl.ttf;


immutable int SCREEN_W = 480;
immutable int SCREEN_H = 720;
immutable int baseSpeed = 12;
immutable ushort baseAnimTick = 6;

struct Vector2 {
	double x;
	double y;
}

abstract class Entity {
	protected SDL_Renderer* renderer;
	protected Collider collider;

	protected bool moving;
	protected int speed;
	protected Vector2 vel;
	protected Vector2 pos;
	protected int rot;
	protected int[2][2] sourceD; // [ [w, h], [w, h] ] for rendering the correct size
	protected SDL_Texture*[2] textures;
	protected ushort currentTexture;
	protected ushort animTick; // time to the next animation
	

	this(SDL_Renderer* gRenderer, int spawnX, int spawnY)
	in {
		assert(&gRenderer !is null);
		assert(spawnX >= 0);
		assert(spawnY >= 0);
		assert(spawnX <= SCREEN_W);
		assert(spawnY <= SCREEN_H);
	} do {
		renderer = gRenderer;

		moving = false;
		vel = Vector2(0, 0);
		pos = Vector2(spawnX, spawnY);
		rot = 0;
		currentTexture = 0;
		animTick = 0;

		SDL_Rect cS = SDL_Rect(0, 0, 100, 100);
		collider = new Collider(&cS, this);
	}

	~this(){
		collider.destroy();
		SDL_DestroyTexture(textures[0]);
		SDL_DestroyTexture(textures[1]);
	}

	protected SDL_Texture* indexTexture(const(char)* path, ushort animIndex)
	in {
		assert(IMG_Load(path) != null);
		assert(animIndex < 2);
	} out (output){
		assert(output != null);
	} do {
		SDL_Surface* surface = IMG_Load(path);

		assert(path != null);

		sourceD[animIndex][0] = surface.w;
		sourceD[animIndex][1] = surface.h;

		pos.x -= sourceD[currentTexture][0] / 4;
		pos.y -= sourceD[currentTexture][1] / 4;

		SDL_Texture* output = SDL_CreateTextureFromSurface(renderer, surface);
		return output;
	}

	protected void render(){
		Vector2 dstrectVector = Vector2(pos.x - sourceD[currentTexture][0] / 2, pos.y - sourceD[currentTexture][1] / 2);
		SDL_Rect dstrect = SDL_Rect(to!int(dstrectVector.x), to!int(dstrectVector.y), sourceD[currentTexture][0], sourceD[currentTexture][1]);
		SDL_RenderCopyEx(renderer, textures[currentTexture], null, &dstrect, rot, null, SDL_FLIP_NONE);
	}


	public void update(){
		if(vel.x != 0 || vel.y != 0){
			moving = true;
			animTick++;
		} else {
			moving = false;
		}

		render();
		collider.update();

		pos.x += vel.x * speed;
		pos.y += vel.y * speed;

		if(animTick >= baseAnimTick){
			final switch(currentTexture){
				case 0:
					currentTexture = 1;
					break;
				case 1:
					currentTexture = 0;
					break;
			}
			animTick = 0;
		}
	}

	public Collider getCollider(){
		return collider;
	}

	public void setPos(Vector2 to){
		pos = to;
	}

	public Vector2 getPos(){
		return pos;
	}
}

class Player : Entity {

	this(SDL_Renderer* gRenderer, int spawnX, int spawnY){
		super(gRenderer, spawnX, spawnY);
		speed = baseSpeed;
		textures[0] = indexTexture("assets/art/playerGrey_up1.png", 0);
		textures[1] = indexTexture("assets/art/playerGrey_up2.png", 1);
	}

	override public void update(){
		super.update();
		takeInput();
	}

	private void takeInput(){
		Uint8* state = SDL_GetKeyboardState(null);
		vel = Vector2(0, 0);
		if(state[SDL_SCANCODE_LEFT] && pos.x > 0){
			vel.x += -1;
			rot = 270;
		}
		if(state[SDL_SCANCODE_RIGHT] && pos.x < SCREEN_W){
			vel.x += 1;
			rot = 90;
		}
		if(state[SDL_SCANCODE_UP] && pos.y > 0){
			vel.y += -1;
			rot = 0;
		}
		if(state[SDL_SCANCODE_DOWN] && pos.y < SCREEN_H){
			vel.y += 1;
			rot = 180;
		}
		if(vel.x != 0 || vel.y != 0){
			vel = normalise(vel);
		}
	}
}

class Enemy : Entity {
	private int eType;
	private ushort index;
	private Enemy[25]* arr;
	private Player* player;
	private bool* flag;

	this(SDL_Renderer* gRenderer, int spawnX, int spawnY, Enemy[25]* a, ushort aI, Player* plr, bool* flg){
		super(gRenderer, spawnX, spawnY);
		speed = baseSpeed - 2;
		eType = uniform(0, 3);
		index = aI;
		arr = a;
		player = plr;
		flag = flg;

		final switch(eType){
			case 0:
				textures[0] = indexTexture("assets/art/enemySwimming_1.png", 0);
				textures[1] = indexTexture("assets/art/enemySwimming_2.png", 1);
				break;
			case 1:
				textures[0] = indexTexture("assets/art/enemyWalking_1.png", 0);
				textures[1] = indexTexture("assets/art/enemyWalking_2.png", 1);
				break;
			case 2:
				textures[0] = indexTexture("assets/art/enemyFlyingAlt_1.png", 0);
				textures[1] = indexTexture("assets/art/enemyFlyingAlt_2.png", 1);
				break;
		}

		final switch(uniform(0, 4)){
			// 0 top; 1 right; 2 bottom; 3 left
			case 0:
				pos = Vector2(uniform(0, SCREEN_W + 1), 0);
				rot = 90;
				rot += uniform(-40, 41);
				break;
			case 1:
				pos = Vector2(SCREEN_W, uniform(0, SCREEN_H + 1));
				rot = 180;
				rot += uniform(-40, 41);
				break;
			case 2:
				pos = Vector2(uniform(0, SCREEN_W + 1), SCREEN_H);
				rot = 270;
				rot += uniform(-40, 41);
				break;
			case 3:
				pos = Vector2(0, uniform(0, SCREEN_H + 1));
				rot = 0;
				rot += uniform(-40, 41);
				break;
		}

		vel = Vector2(cos(to!double(rot * (PI / 180))), sin(to!double(rot * (PI / 180))));
	}

	~this(){
		(*arr)[index] = null;
	}

	override public void update(){
		if(pos.x < -100 || pos.x > SCREEN_W + 100 || pos.y < -100 || pos.y > SCREEN_H + 100){
			this.destroy();
			return;
		}

		if(collider.isColliding(*player)){
			*flag = false;
		}

		super.update();
	}
}

class Timer {
	private Uint32 startTick; // SDL_GetTicks()
	private Uint32 stopTick;
	private Uint32 runningTicks;
	private bool running;

	this(){
		startTick = 0;
		startTick = 0;
		runningTicks = 0;
		running = false;
	}

	public void start(){
		if(!running){
			startTick = SDL_GetTicks();
			running = true;
		}
	}

	public void stop(){
		running = false;
		stopTick = SDL_GetTicks();
		runningTicks = stopTick - startTick;
	}

	public void reset(){
		startTick = 0;
		stopTick = 0;
		runningTicks = 0;
	}

	public Uint32 getRunningTicks(){
		if(running){
			runningTicks = SDL_GetTicks() - startTick;
		}
		return runningTicks;
	}
}

class Collider {
	private SDL_Rect shape;
	private Entity parent;

	this(SDL_Rect* rect, Entity par){
		shape = *rect;
		parent = par;
	}

	public void update(){
		shape.x = to!int(parent.pos.x) - shape.w / 2;
		shape.y = to!int(parent.pos.y) - shape.h / 2;
	}

	public bool isColliding(Entity e){
			if(shape.x > e.getCollider().shape.x + e.getCollider().shape.w){
				return false;
			}
			if(shape.x + shape.w < e.getCollider().shape.x){
				return false;
			}
			if(shape.y > e.getCollider().shape.y + e.getCollider().shape.h){
				return false;
			}
			if(shape.y + shape.h < e.getCollider().shape.y){
				return false;
			}
			return true;
	}
}

class Button {
	private SDL_Renderer* renderer;
	private TTF_Font* font;

	private Vector2 pos;
	private SDL_Texture*[2] textures; // 0 default; 1 hover
	private bool enabled; // visible and clickable or not
	private ushort state; // 0 default; 1 hover

	private Vector2 dim;

	this(SDL_Renderer* gRenderer, int spawnX, int spawnY)
	in {
		assert(&gRenderer !is null);
		assert(spawnX >= 0);
		assert(spawnY >= 0);
		assert(spawnX <= SCREEN_W);
		assert(spawnY <= SCREEN_H);
	} do {
		renderer = gRenderer;
		font = TTF_OpenFont("assets/fonts/Xolonium-Regular.ttf", 50);
		enabled = true;
		state = 0;
		pos.x = spawnX;
		pos.y = spawnY;

		dim = Vector2(200, 100);

		// default surface
		SDL_Surface* def = SDL_CreateRGBSurface(0, to!int(dim.x), to!int(dim.y), 32, 0, 0, 0, 0);
		SDL_Surface* defText = TTF_RenderText_Solid(font, "Start", SDL_Color(0xAA, 0xAA, 0xAA, 0xFF));
		SDL_FillRect(def, null, SDL_MapRGB(def.format, 0x51, 0x51, 0x51));
		SDL_Rect defdstrect = SDL_Rect((to!int(dim.x) / 2) - (defText.w / 2), (to!int(dim.y) / 2) - (defText.h / 2), 0, 0);
		SDL_BlitSurface(defText, null, def, &defdstrect);

		// hover
		SDL_Surface* hov = SDL_CreateRGBSurface(0, to!int(dim.x), to!int(dim.y), 32, 0, 0, 0, 0);
		SDL_Surface* hovText = TTF_RenderText_Solid(font, "Start", SDL_Color(0xAA, 0xAA, 0xAA, 0xFF));
		SDL_FillRect(hov, null, SDL_MapRGB(hov.format, 0x3A, 0x3A, 0x3A));
		SDL_Rect hovdstrect = SDL_Rect((to!int(dim.x) / 2) - (hovText.w / 2), (to!int(dim.y) / 2) - (hovText.h / 2), 0, 0);
		SDL_BlitSurface(hovText, null, hov, &hovdstrect);

		textures[0] = SDL_CreateTextureFromSurface(renderer, def);
		textures[1] = SDL_CreateTextureFromSurface(renderer, hov);


		SDL_FreeSurface(def);
		SDL_FreeSurface(defText);
		SDL_FreeSurface(hov);
		SDL_FreeSurface(hovText);
	}

	~this(){
		SDL_DestroyTexture(textures[0]);
		SDL_DestroyTexture(textures[1]);
		TTF_CloseFont(font);
	}

	private void render(){
		Vector2 dstrectVector = Vector2(pos.x - dim.x / 2, pos.y - dim.y / 2);
		SDL_Rect dstrect = SDL_Rect(to!int(dstrectVector.x), to!int(dstrectVector.y), to!int(dim.x), to!int(dim.y));
		SDL_RenderCopy(renderer, textures[state], null, &dstrect);
	}

	public void update(){
		if(enabled){
			render();

			int x, y;
			SDL_GetMouseState(&x, &y);
			if(getMouseIn(x, y)){
				state = 1;
			} else {
				state = 0;
			}
		}
	}

	// update stored mouse position
	public void waitMouse(SDL_Event* event){
		if(event.type == SDL_MOUSEBUTTONDOWN){
			int x, y;
			SDL_GetMouseState(&x, &y);


			if(getMouseIn(x, y)){
				enabled = false;
			}
		}
	}

	public void setEnabled(bool to){
		enabled = to;
	}

	public bool getEnabled(){
		return enabled;
	}

	private bool getMouseIn(int iX, int iY)
	in {
		assert(iX >= 0);
		assert(iY >= 0);
		assert(iX <= SCREEN_W);
		assert(iY <= SCREEN_H);
	} do {
		bool mouseIn = true;
		if(iX > pos.x + dim.x / 2){
			mouseIn = false;
		}
		if(iX < pos.x - dim.x / 2){
			mouseIn = false;
		}
		if(iY > pos.y + dim.y / 2){
			mouseIn = false;
		}
		if(iY < pos.y - dim.y / 2){
			mouseIn = false;
		}

		return mouseIn;
	}
}

class Text {
	private SDL_Renderer* renderer;
	private TTF_Font* font;

	private Vector2 pos;
	private SDL_Texture* texture;
	private bool enabled;
	private string text;

	private Vector2 dim;

	this(SDL_Renderer* gRenderer, int spawnX, int spawnY, bool en)
	in {
		assert(&gRenderer !is null);
		assert(spawnX >= 0);
		assert(spawnY >= 0);
		assert(spawnX <= SCREEN_W);
		assert(spawnY <= SCREEN_H);
	} do {
		renderer = gRenderer;
		font = TTF_OpenFont("assets/fonts/Xolonium-Regular.ttf", 50);
		pos.x = spawnX;
		pos.y = spawnY;
		dim.x = 0;
		dim.y = 0;

		enabled = en;

		text = "text failure!";
		
	}

	~this(){
		SDL_DestroyTexture(texture);
		TTF_CloseFont(font);
	}

	private void render(){
		Vector2 dstrectVector = Vector2(pos.x - dim.x / 2, pos.y - dim.y / 2);
		SDL_Rect dstrect = SDL_Rect(to!int(dstrectVector.x), to!int(dstrectVector.y), to!int(dim.x), to!int(dim.y));
		SDL_RenderCopy(renderer, texture, null, &dstrect);
	}

	public void update(){
		if(enabled){
			SDL_Surface* surface = TTF_RenderText_Solid(font, toStringz(text), SDL_Color(0x3A, 0x3A, 0x3A, 0xFF));
			texture = SDL_CreateTextureFromSurface(renderer, surface);

			dim = Vector2(surface.w, surface.h);

			render();

		}
	}

	public void setEnabled(bool to){
		enabled = to;
	}

	public bool getEnabled(){
		return enabled;
	}

	public void setText(string to){
		text = to;
	}
}

Vector2 normalise(Vector2 v)
do {
	double vx, vy;
	if(v.x != 0){
		vx = v.x / sqrt(v.x * v.x);
	} else {
		vx = 0;
	}
	if(v.y != 0){
		vy = v.y / sqrt(v.y * v.y);
	} else {
		vy = 0;
	}
	return Vector2(vx, vy);
}

