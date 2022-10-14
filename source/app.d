/* 
	A remake of the Godot Engine's introductory 2D game, "Dodge the Creeps", produced with the SDL library to the best of my ability.
*/

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


import std.stdio : writeln;
import std.random : uniform;
import std.conv : to;
import bindbc.sdl;
import bindbc.sdl.image;
import bindbc.sdl.ttf;
import modules.classes;
extern (C) int getch();

SDL_Window* mainWindow;
SDL_Renderer* mainRenderer;
Player player;
Enemy[25] entities = null; // space allocated for 25 entities
bool alive = false;

Mix_Music* music;
Mix_Chunk* death;

immutable int SCREEN_W = 480;
immutable int SCREEN_H = 720;
immutable int FPS = 30;
immutable int PRESTART = 4000;

int minSpawnNext = 500;
int maxSpawnNext = 1500;

void init(){
	mainWindow = SDL_CreateWindow("Dodge The Creeps!", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, SCREEN_W, SCREEN_H, SDL_WINDOW_SHOWN);
	mainRenderer = SDL_CreateRenderer(mainWindow, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
	SDL_SetRenderDrawColor(mainRenderer, 0x29, 0x7C, 0x66, 0xFF);
	SDL_RenderClear(mainRenderer);

	death = Mix_LoadWAV("assets/art/gameover.wav");
	music = Mix_LoadMUS("assets/art/HouseInAForest.ogg");

	player = new Player(mainRenderer, SCREEN_W / 2, SCREEN_H / 2);
}

void createEnemy(){
	for(ushort i; i < entities.length; i++){
		// place a new enemy in the first available null spot
		if(entities[i] is null){
			entities[i] = new Enemy(mainRenderer, 0, 0, &entities, i, &player, &alive);
			return;
		}
	}
}

void main(){
	bool operational = true;
	SDLSupport ret = loadSDL();
	if(ret != sdlSupport){
		writeln("Could not find SDL DLL!");
		operational = false;
	}
	if(loadSDLImage() != sdlImageSupport){
		writeln("Could not find SDL Image DLL!");
		operational = false;
	}
	if(loadSDLTTF() != sdlTTFSupport){
		writeln("Could not find SDL TTF DLL!");
		operational = false;
	}
	if(loadSDLMixer != sdlMixerSupport){
		writeln("Could not find SDL Mixer DLL!");
		operational = false;
	}

	if(SDL_Init(SDL_INIT_EVERYTHING) != 0){
		writeln("SDL has failed to start!");
		operational = false;
	}
	if(IMG_Init(IMG_INIT_PNG) != IMG_INIT_PNG){
		writeln("SDL Image has failed to start!");
		operational = false;
	}
	if(TTF_Init() != 0){
		writeln("SDL TTF has failed to start!");
		operational = false;
	}
	if(Mix_OpenAudio(44100, MIX_DEFAULT_FORMAT, 2, 2048) < 0){
		writeln("SDL Mixer has failed to start!");
		operational = false;
	}

	// skip everything if error above
	if(operational){
		init();
		bool quit = false;

		uint spawnNext = PRESTART;

		SDL_Event event;
		Timer spawn = new Timer;
		Timer delta = new Timer;
		Timer score = new Timer;

		Button startButton = new Button(mainRenderer, SCREEN_W / 2, (SCREEN_H / 2) + (SCREEN_H / 11));
		Text scoreText = new Text(mainRenderer, SCREEN_W / 2, 40, true);
		scoreText.setText(" ");

		Text splashText1 = new Text(mainRenderer, SCREEN_W / 2, 250, true);
		splashText1.setText("Evade the");
		Text splashText2 = new Text(mainRenderer, SCREEN_W / 2, 300, true);
		splashText2.setText("Creeps!");

		int scoreCounter = 0;

		bool needPlayDead = true; // formerly called justDied for unknown reasons ok

		while(!quit){
			delta.start();
			SDL_RenderClear(mainRenderer);

			while(SDL_PollEvent(&event) != 0){
				if(event.type == SDL_QUIT){
					quit = true;
				}

				if(startButton.getEnabled()){
					startButton.waitMouse(&event);
				}
			}

			if(Mix_PlayingMusic() == 0){
				Mix_PlayMusic(music, 0);
			}

			scoreText.update();

			if(!alive){
				if(!needPlayDead){
					needPlayDead = true;
					Mix_PlayChannel(-1, death, 0);
				}
				if(startButton.getEnabled()){
					startButton.update();
					splashText1.update();
					splashText2.update();
				}
				if(!startButton.getEnabled()){
					alive = true;

					// restart game config
					needPlayDead = false;

					for(ushort i; i < entities.length; i++){
						entities[i].destroy();
						entities[i] = null;
					}

					spawn.stop();
					spawn.reset();
					spawnNext = PRESTART;

					score.stop();
					score.reset();

					player.setPos(Vector2(SCREEN_W / 2, SCREEN_H / 2));

					scoreText.setText("0");
					scoreCounter = 0;
				}
			}

			if(alive){
				if(!startButton.getEnabled()){
					startButton.setEnabled(true);
				}

				spawn.start();


				player.update();

				foreach(e; entities){
					if(e !is null){
						e.update();
					}
				}

				SDL_RenderPresent(mainRenderer);

				if(spawn.getRunningTicks() > spawnNext){
					spawnNext = uniform(minSpawnNext, maxSpawnNext);
					spawn.stop();
					spawn.reset();
					createEnemy();

					if(score.getRunningTicks() == 0){
						score.start();
					}
				}

				if(score.getRunningTicks() > scoreCounter * 1000){
					scoreCounter++;
					scoreText.setText(to!string(scoreCounter));
				}

			}

			SDL_RenderPresent(mainRenderer);

			delta.stop();
			// frame rate control
			if(delta.getRunningTicks() < 1000 / FPS){
				SDL_Delay(1000 / FPS - delta.getRunningTicks());
			}
			delta.reset();
		}
	

		SDL_Quit();
		IMG_Quit();
		TTF_Quit();
		Mix_Quit();

		Mix_FreeChunk(death);
		Mix_FreeMusic(music);

		SDL_DestroyRenderer(mainRenderer);
		SDL_DestroyWindow(mainWindow);

	}

	if(!operational){
		writeln("Critical failure! Ensure all files are in the correct locations before trying again.");
		writeln("Press any key to exit:");
		//getch();
	}

	return;
}