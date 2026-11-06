#!/usr/bin/env python3
"""Sinh project.yml (XcodeGen) cho Catnip theo các tuỳ chọn build, thay cho heredoc trong workflow.

Biến môi trường:
  BUNDLE_ID, MARKETING_VERSION, BUILD_NUMBER      (bắt buộc)
  WITH_LOVE=true  + LOVE_DIR, LOVE_LIB            nhúng lõi LÖVE
  CONFIG                                          tên cấu hình build (Debug/Release hoặc tên tuỳ ý như Beta, Preview)
  WITH_ISH=true   + ISH_CORE                      nhúng iSH (thư mục ish-core do tools/build_ish_core.sh tạo)
"""
import os
import sys

env = os.environ.get
with_love = env("WITH_LOVE") == "true"
with_ish = env("WITH_ISH") == "true"

sources = ["main.swift", "Models.swift", "Storage.swift", "UI.swift", "Editor.swift", "EditorSidebar.swift",
           "GameRun.swift", "Fonts.swift", "Themes.swift", "MarkdownPreview.swift", "Docs.swift", "Shell.swift"]
resources = ["Resources"]
ldflags = ["$(inherited)"]
header_paths = ["$(inherited)"]
framework_paths = ["$(inherited)"]
swift_conditions = ["$(inherited)"]
gcc_defs = ["$(inherited)"]
deps = []
packages = {}
bridging = False
extra_settings = {}

if with_love:
    love_dir = env("LOVE_DIR"); love_lib = env("LOVE_LIB")
    if not (love_dir and love_lib):
        sys.exit("WITH_LOVE cần LOVE_DIR và LOVE_LIB")
    xc = f"{love_dir}/platform/xcode"
    sources += ["LoveBridge.mm", "LoveBridge.h"]
    bridging = True
    swift_conditions.append("CATNIP_HAS_LOVE")
    gcc_defs.append("CATNIP_HAS_LOVE=1")
    extra_settings.update({"CLANG_CXX_LANGUAGE_STANDARD": "c++17", "CLANG_CXX_LIBRARY": "libc++"})
    header_paths += [f"{love_dir}/src", f"{love_dir}/src/libraries", f"{love_dir}/src/modules",
                     f"{xc}/ios/libraries/Lua.xcframework/ios-arm64/Headers"]
    framework_paths.append(f"{xc}/shared/Frameworks/SDL3.xcframework/ios-arm64")
    ldflags += ["-ObjC", love_lib]
    deps.append({"framework": f"{xc}/shared/Frameworks/SDL3.xcframework", "embed": True, "codeSign": False})
    for name in ["Lua", "freetype", "harfbuzz", "modplug", "ogg", "theora", "vorbis"]:
        deps.append({"framework": f"{xc}/ios/libraries/{name}.xcframework", "embed": False})
    for sdk in ["AVFoundation", "AudioToolbox", "CoreGraphics", "CoreHaptics", "CoreMotion", "GameController",
                "Metal", "OpenAL", "OpenGLES", "QuartzCore", "UIKit"]:
        deps.append({"sdk": f"{sdk}.framework"})
    deps += [{"sdk": "libz.tbd"}, {"sdk": "libbz2.tbd"}, {"sdk": "libc++.tbd"}]

if with_ish:
    core = env("ISH_CORE")
    if not core:
        sys.exit("WITH_ISH cần ISH_CORE")
    sources += ["IshBridge.m", "IshBridge.h", "IshShell.swift"]
    resources.append(f"{core}/Resources")      # root.tar.gz, repositories.txt (do workflow chép vào)
    bridging = True
    swift_conditions.append("CATNIP_HAS_ISH")
    gcc_defs.append("CATNIP_HAS_ISH=1")
    header_paths.append(f"{core}/ish")
    ldflags += [f"{core}/lib/{n}" for n in ("libish.a", "libish_emu.a", "libfakefs.a", "libfakefs_import.a", "libarchive.a")]
    ldflags += ["-lsqlite3", "-lbz2", "-liconv", "-lresolv", "-lz"]
    packages["SwiftTerm"] = {"url": "https://github.com/migueldeicaza/SwiftTerm", "exactVersion": "1.17.0"}
    deps.append({"package": "SwiftTerm"})

base = {
    "PRODUCT_BUNDLE_IDENTIFIER": env("BUNDLE_ID"),
    "MARKETING_VERSION": env("MARKETING_VERSION"),
    "CURRENT_PROJECT_VERSION": env("BUILD_NUMBER"),
    "GENERATE_INFOPLIST_FILE": "YES",
    "INFOPLIST_KEY_UILaunchScreen_Generation": "YES",
    "INFOPLIST_KEY_CFBundleDisplayName": "Catnip",
    "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents": "YES",
    "INFOPLIST_KEY_UISupportedInterfaceOrientations":
        "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight",
    "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad":
        "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown "
        "UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight",
    "SWIFT_VERSION": "5.9",
    "TARGETED_DEVICE_FAMILY": "1,2",
}
if bridging:
    base["CLANG_ENABLE_OBJC_ARC"] = "YES"
    base["SWIFT_OBJC_BRIDGING_HEADER"] = "Catnip-Bridging-Header.h"
    base["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = " ".join(swift_conditions)
    base["GCC_PREPROCESSOR_DEFINITIONS"] = " ".join(gcc_defs)
    base["HEADER_SEARCH_PATHS"] = " ".join(header_paths)
    base["OTHER_LDFLAGS"] = " ".join(ldflags)
    if len(framework_paths) > 1:
        base["FRAMEWORK_SEARCH_PATHS"] = " ".join(framework_paths)
    base.update(extra_settings)
if with_ish:
    # Lõi iSH được build với deployment target thấp; chỉ cảnh báo, không làm hỏng liên kết.
    base["OTHER_LDFLAGS"] += " -Wl,-w"

# Bridging header chỉ nhập header của bản nhúng tương ứng, nên các file .h/.mm phải nằm trong sources.
sources += ["Catnip-Bridging-Header.h"] if bridging else []


def q(v):
    """Trích dẫn giá trị YAML một cách an toàn."""
    if isinstance(v, bool):
        return "true" if v else "false"
    s = str(v).replace("\\", "\\\\").replace('"', '\\"')
    return f'"{s}"'


# Mọi tên cấu hình workflow cho chọn phải có trong project, nếu không Xcode build app và gói SPM
# vào hai thư mục khác nhau (lỗi "SwiftTerm_SwiftTerm.bundle: No such file"). Tên lạ được coi là bản release.
configs = {"Debug": "debug", "Release": "release"}
config = env("CONFIG") or "Release"
configs.setdefault(config, "release")

out = ["name: Catnip", "configs:"]
out += [f"  {name}: {kind}" for name, kind in configs.items()]
out += ["options:", "  deploymentTarget:", '    iOS: "15.0"', "  createIntermediateGroups: true"]
if packages:
    out.append("packages:")
    for name, p in packages.items():
        out.append(f"  {name}:")
        for k, v in p.items():
            out.append(f"    {k}: {q(v)}")
out += ["targets:", "  Catnip:", "    type: application", "    platform: iOS", "    sources:"]
for s in sources:
    out.append(f"      - {q(s)}")
for r in resources:
    if r == "Resources" or r.endswith("/Resources"):
        out += [f"      - path: {q(r)}", "        buildPhase: resources"]
out.append("    settings:")
out.append("      base:")
for k, v in base.items():
    out.append(f"        {k}: {q(v)}")
if deps:
    out.append("    dependencies:")
    for d in deps:
        first = True
        for k, v in d.items():
            prefix = "      - " if first else "        "
            out.append(f"{prefix}{k}: {q(v)}")
            first = False
print("\n".join(out))
