//
//  Catnip Engine: game maker for IOS
//
//  Licensed under GPL-3.0-or-later. See LICENSE.
//

#import "CppInput.h"

#ifdef CATNIP_HAS_LOVE

#include <SDL3/SDL.h>
#include <string.h>
#include <stdlib.h>

namespace {

SDL_Window *mainWindow() {
	SDL_Window *w = SDL_GetKeyboardFocus();
	if (!w) w = SDL_GetMouseFocus();
	if (!w) {
		int n = 0;
		SDL_Window **ws = SDL_GetWindows(&n);
		if (ws && n > 0) w = ws[0];
		if (ws) SDL_free(ws);
	}
	return w;
}

struct KeyDef { const char *name; SDL_Scancode sc; SDL_Keycode kc; };

const KeyDef kKeys[] = {
	{"Space", SDL_SCANCODE_SPACE, SDLK_SPACE}, {"Enter", SDL_SCANCODE_RETURN, SDLK_RETURN},
	{"Esc", SDL_SCANCODE_ESCAPE, SDLK_ESCAPE}, {"Tab", SDL_SCANCODE_TAB, SDLK_TAB},
	{"Backspace", SDL_SCANCODE_BACKSPACE, SDLK_BACKSPACE}, {"Delete", SDL_SCANCODE_DELETE, SDLK_DELETE},
	{"Shift", SDL_SCANCODE_LSHIFT, SDLK_LSHIFT}, {"Ctrl", SDL_SCANCODE_LCTRL, SDLK_LCTRL},
	{"Alt", SDL_SCANCODE_LALT, SDLK_LALT},
	{"Up", SDL_SCANCODE_UP, SDLK_UP}, {"Down", SDL_SCANCODE_DOWN, SDLK_DOWN},
	{"Left", SDL_SCANCODE_LEFT, SDLK_LEFT}, {"Right", SDL_SCANCODE_RIGHT, SDLK_RIGHT},
	{"Home", SDL_SCANCODE_HOME, SDLK_HOME}, {"End", SDL_SCANCODE_END, SDLK_END},
	{"PageUp", SDL_SCANCODE_PAGEUP, SDLK_PAGEUP}, {"PageDown", SDL_SCANCODE_PAGEDOWN, SDLK_PAGEDOWN},
	{"F1", SDL_SCANCODE_F1, SDLK_F1}, {"F2", SDL_SCANCODE_F2, SDLK_F2}, {"F3", SDL_SCANCODE_F3, SDLK_F3},
	{"F4", SDL_SCANCODE_F4, SDLK_F4}, {"F5", SDL_SCANCODE_F5, SDLK_F5}, {"F6", SDL_SCANCODE_F6, SDLK_F6},
	{"F7", SDL_SCANCODE_F7, SDLK_F7}, {"F8", SDL_SCANCODE_F8, SDLK_F8}, {"F9", SDL_SCANCODE_F9, SDLK_F9},
	{"F10", SDL_SCANCODE_F10, SDLK_F10}, {"F11", SDL_SCANCODE_F11, SDLK_F11}, {"F12", SDL_SCANCODE_F12, SDLK_F12},
};

bool lookupKey(const char *name, SDL_Scancode &sc, SDL_Keycode &kc) {
	if (strlen(name) == 1) {
		char c = name[0];
		if (c >= 'A' && c <= 'Z') { sc = (SDL_Scancode)(SDL_SCANCODE_A + (c - 'A')); kc = (SDL_Keycode)('a' + (c - 'A')); return true; }
		if (c >= 'a' && c <= 'z') { sc = (SDL_Scancode)(SDL_SCANCODE_A + (c - 'a')); kc = (SDL_Keycode)c; return true; }
		if (c >= '1' && c <= '9') { sc = (SDL_Scancode)(SDL_SCANCODE_1 + (c - '1')); kc = (SDL_Keycode)c; return true; }
		if (c == '0') { sc = SDL_SCANCODE_0; kc = (SDL_Keycode)'0'; return true; }
	}
	for (const KeyDef &k : kKeys) {
		if (strcmp(k.name, name) == 0) { sc = k.sc; kc = k.kc; return true; }
	}
	return false;
}

SDL_Keymod gMod = SDL_KMOD_NONE;
float gX = 0, gY = 0;
SDL_MouseButtonFlags gButtons = 0;

}

@implementation CatnipInput

+ (BOOL)hasWindow { return mainWindow() != NULL; }

+ (void)sendKeyNamed:(NSString *)name down:(BOOL)down {
	SDL_Scancode sc; SDL_Keycode kc;
	if (!lookupKey(name.UTF8String, sc, kc)) return;
	if (sc == SDL_SCANCODE_LSHIFT) gMod = down ? (SDL_Keymod)(gMod | SDL_KMOD_LSHIFT) : (SDL_Keymod)(gMod & ~SDL_KMOD_LSHIFT);
	if (sc == SDL_SCANCODE_LCTRL)  gMod = down ? (SDL_Keymod)(gMod | SDL_KMOD_LCTRL)  : (SDL_Keymod)(gMod & ~SDL_KMOD_LCTRL);
	if (sc == SDL_SCANCODE_LALT)   gMod = down ? (SDL_Keymod)(gMod | SDL_KMOD_LALT)   : (SDL_Keymod)(gMod & ~SDL_KMOD_LALT);
	SDL_Window *w = mainWindow();
	SDL_Event e;
	SDL_zero(e);
	e.type = down ? SDL_EVENT_KEY_DOWN : SDL_EVENT_KEY_UP;
	e.key.timestamp = SDL_GetTicksNS();
	e.key.windowID = w ? SDL_GetWindowID(w) : 0;
	e.key.scancode = sc;
	e.key.key = kc;
	e.key.mod = gMod;
	e.key.down = down;
	e.key.repeat = false;
	SDL_PushEvent(&e);
}

+ (void)moveMouseToX:(double)nx y:(double)ny {
	SDL_Window *w = mainWindow();
	int iw = 0, ih = 0;
	if (w) SDL_GetWindowSize(w, &iw, &ih);
	if (iw <= 0 || ih <= 0) return;
	float x = (float)(fmin(fmax(nx, 0), 1) * iw), y = (float)(fmin(fmax(ny, 0), 1) * ih);
	SDL_Event e;
	SDL_zero(e);
	e.type = SDL_EVENT_MOUSE_MOTION;
	e.motion.timestamp = SDL_GetTicksNS();
	e.motion.windowID = SDL_GetWindowID(w);
	e.motion.state = gButtons;
	e.motion.x = x;
	e.motion.y = y;
	e.motion.xrel = x - gX;
	e.motion.yrel = y - gY;
	gX = x; gY = y;
	SDL_PushEvent(&e);
}

+ (void)mouseButton:(int)button down:(BOOL)down {
	SDL_Window *w = mainWindow();
	SDL_MouseButtonFlags mask = SDL_BUTTON_MASK(button);
	gButtons = down ? (gButtons | mask) : (gButtons & ~mask);
	SDL_Event e;
	SDL_zero(e);
	e.type = down ? SDL_EVENT_MOUSE_BUTTON_DOWN : SDL_EVENT_MOUSE_BUTTON_UP;
	e.button.timestamp = SDL_GetTicksNS();
	e.button.windowID = w ? SDL_GetWindowID(w) : 0;
	e.button.button = (Uint8)button;
	e.button.down = down;
	e.button.clicks = 1;
	e.button.x = gX;
	e.button.y = gY;
	SDL_PushEvent(&e);
}

+ (void)scrollX:(double)x y:(double)y {
	SDL_Window *w = mainWindow();
	SDL_Event e;
	SDL_zero(e);
	e.type = SDL_EVENT_MOUSE_WHEEL;
	e.wheel.timestamp = SDL_GetTicksNS();
	e.wheel.windowID = w ? SDL_GetWindowID(w) : 0;
	e.wheel.x = (float)x;
	e.wheel.y = (float)y;
	e.wheel.direction = SDL_MOUSEWHEEL_NORMAL;
	e.wheel.mouse_x = gX;
	e.wheel.mouse_y = gY;
	SDL_PushEvent(&e);
}

+ (void)startTextInput {
	SDL_Window *w = mainWindow();
	if (w) SDL_StartTextInput(w);
}

+ (void)stopTextInput {
	SDL_Window *w = mainWindow();
	if (w) SDL_StopTextInput(w);
}

+ (void)requestQuit {
	SDL_Event e;
	SDL_zero(e);
	e.type = SDL_EVENT_QUIT;
	e.quit.timestamp = SDL_GetTicksNS();
	SDL_PushEvent(&e);
}

@end

#else

@implementation CatnipInput
+ (BOOL)hasWindow { return NO; }
+ (void)sendKeyNamed:(NSString *)name down:(BOOL)down {}
+ (void)moveMouseToX:(double)nx y:(double)ny {}
+ (void)mouseButton:(int)button down:(BOOL)down {}
+ (void)scrollX:(double)x y:(double)y {}
+ (void)startTextInput {}
+ (void)stopTextInput {}
+ (void)requestQuit {}
@end

#endif
