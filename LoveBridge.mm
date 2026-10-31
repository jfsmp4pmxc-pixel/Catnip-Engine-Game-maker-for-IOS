//
//  Catnip Engine: game maker for IOS
//
//  Copyright (C) 2026 jfsmp4pmxc-pixel <ihhjnkk@gmail.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program. If not, see <https://www.gnu.org/licenses/>.
//

// LoveBridge.mm
// Khởi động lõi LÖVE (liblove) từ bên trong app Catnip.
//
// LÖVE vốn có hàm main() riêng (love.cpp, chỉ build khi LOVE_BUILD_EXE) nên không nằm trong liblove.a.
// File này viết lại phần `runlove` của LÖVE cho trường hợp nhúng: tạo Lua state, nạp module "love",
// chạy love.boot với đường dẫn dự án, rồi trả quyền điều khiển lại cho Catnip khi game thoát.
// LÖVE (zlib license) © LÖVE Development Team.

#import "LoveBridge.h"
#import <UIKit/UIKit.h>

// Catnip có UIApplicationMain riêng, nên SDL không được chiếm hàm main.
#define SDL_MAIN_HANDLED

#include "common/runtime.h"
#include "common/Variant.h"
#include "modules/love/love.h"

#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>

extern "C" {
	#include <lua.h>
	#include <lualib.h>
	#include <lauxlib.h>
}

#include <cstring>
#include <string>

namespace
{

enum DoneAction
{
	DONE_QUIT,
	DONE_RESTART,
};

int preload(lua_State *L, lua_CFunction f, const char *name)
{
	lua_getglobal(L, "package");
	lua_getfield(L, -1, "preload");
	lua_pushcfunction(L, f);
	lua_setfield(L, -2, name);
	lua_pop(L, 2);
	return 0;
}

// Tương đương runlove() trong love.cpp của LÖVE, rút gọn cho một đường dẫn game.
DoneAction runLoveOnce(const std::string &gamePath, int &retval, love::Variant &restartvalue)
{
	lua_State *L = luaL_newstate();
	luaL_openlibs(L);

	// Cài đặt riêng cho LuaJIT, cần làm sớm nhất có thể.
	preload(L, luaopen_love_jitsetup, "love.jitsetup");
	lua_getglobal(L, "require");
	lua_pushstring(L, "love.jitsetup");
	lua_call(L, 1, 0);

	// Cho phép require "love".
	preload(L, luaopen_love, "love");

	// Bảng arg toàn cục, giống chương trình Lua độc lập: arg[1] = đường dẫn game.
	lua_newtable(L);
	lua_pushstring(L, "catnip");
	lua_rawseti(L, -2, -2);
	lua_pushstring(L, "embedded boot.lua");
	lua_rawseti(L, -2, -1);
	lua_pushstring(L, gamePath.c_str());
	lua_rawseti(L, -2, 1);
	lua_setglobal(L, "arg");

	// require "love"
	lua_getglobal(L, "require");
	lua_pushstring(L, "love");
	lua_call(L, 1, 1);

	// Chạy ở chế độ "exe" (giống bản love độc lập), và truyền lại giá trị restart nếu có.
	lua_pushboolean(L, 1);
	lua_setfield(L, -2, "_exe");
	love::luax_pushvariant(L, restartvalue);
	lua_setfield(L, -2, "restart");
	restartvalue = love::Variant();
	lua_pop(L, 1);

	// require "love.boot" trả về hàm boot; chạy nó như một coroutine tới khi xong.
	lua_getglobal(L, "require");
	lua_pushstring(L, "love.boot");
	lua_call(L, 1, 1);

	lua_newthread(L);
	lua_pushvalue(L, -2);
	int stackpos = lua_gettop(L);
	int nres = 0;
	while (love::luax_resume(L, 0, &nres) == LUA_YIELD)
#if LUA_VERSION_NUM >= 504
		lua_pop(L, nres);
#else
		lua_pop(L, lua_gettop(L) - stackpos);
#endif

	retval = 0;
	DoneAction done = DONE_QUIT;

	// love.event.quit("restart") làm boot trả về "restart".
	int retidx = stackpos;
	if (!lua_isnoneornil(L, retidx))
	{
		if (lua_type(L, retidx) == LUA_TSTRING && strcmp(lua_tostring(L, retidx), "restart") == 0)
			done = DONE_RESTART;
		if (lua_isnumber(L, retidx))
			retval = (int) lua_tonumber(L, retidx);

		if (retidx < lua_gettop(L))
			restartvalue = love::luax_checkvariant(L, retidx + 1, false);
	}

	lua_close(L);
	return done;
}

} // namespace

@implementation CatnipLove

+ (NSString *)versionString
{
	return [NSString stringWithUTF8String:love_version()];
}

+ (int)runGameAtPath:(NSString *)path
{
	// SDL được dùng khi không có SDL_main: phải báo "main đã sẵn sàng" một lần.
	static dispatch_once_t once;
	dispatch_once(&once, ^{ SDL_SetMainReady(); });

	std::string gamePath([path UTF8String]);
	int retval = 0;
	love::Variant restartvalue;
	DoneAction done = DONE_QUIT;

	do
	{
		done = runLoveOnce(gamePath, retval, restartvalue);
	} while (done == DONE_RESTART);

	return retval;
}

@end
