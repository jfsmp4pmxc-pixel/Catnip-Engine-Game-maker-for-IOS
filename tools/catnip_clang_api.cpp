// libcatnipclang: bọc Clang Interpreter (clang-repl) + ORC JIT thành API C cho Catnip.
// Biên dịch kèm LLVM/Clang (xem tools/build_clang_pack.sh). Chưa build/kiểm chứng; viết theo LLVM 20.
//
//   int catnip_clang_run(const char *resource_dir, const char *sysroot,
//                        const char *flags_nl, const char *sources_nl, char *err, int errlen);
// flags_nl / sources_nl: danh sách phân tách bằng '\n'. Trả về mã thoát của main(), hoặc -1 nếu lỗi (err có mô tả).

#include "clang/Basic/Diagnostic.h"
#include "clang/Frontend/CompilerInstance.h"
#include "clang/Interpreter/Interpreter.h"
#include "llvm/ExecutionEngine/Orc/Core.h"
#include "llvm/Support/Error.h"
#include "llvm/Support/TargetSelect.h"

#include <cstdio>
#include <cstring>
#include <sstream>
#include <string>
#include <vector>

static std::vector<std::string> splitLines(const char *s) {
  std::vector<std::string> out;
  if (!s) return out;
  std::stringstream ss(s);
  std::string line;
  while (std::getline(ss, line))
    if (!line.empty()) out.push_back(line);
  return out;
}

static void setErr(char *err, int errlen, const std::string &msg) {
  if (!err || errlen <= 0) return;
  std::snprintf(err, (size_t)errlen, "%s", msg.c_str());
}

extern "C" __attribute__((visibility("default")))
int catnip_clang_run(const char *resource_dir, const char *sysroot, const char *flags_nl,
                     const char *sources_nl, char *err, int errlen) {
  llvm::InitializeNativeTarget();
  llvm::InitializeNativeTargetAsmPrinter();

  std::vector<std::string> flagStrs = splitLines(flags_nl);
  std::vector<std::string> sources = splitLines(sources_nl);
  if (sources.empty()) { setErr(err, errlen, "Không có file nguồn."); return -1; }

  std::vector<const char *> args;
  std::string res = std::string("-resource-dir=") + (resource_dir ? resource_dir : "");
  args.push_back("-isysroot");
  args.push_back(sysroot);
  args.push_back(res.c_str());
  args.push_back("-fno-color-diagnostics");
  for (auto &f : flagStrs) args.push_back(f.c_str());

  clang::IncrementalCompilerBuilder CB;
  CB.SetCompilerArgs(args);
  auto CI = CB.CreateCpp();
  if (!CI) { setErr(err, errlen, llvm::toString(CI.takeError())); return -1; }

  auto Interp = clang::Interpreter::create(std::move(*CI));
  if (!Interp) { setErr(err, errlen, llvm::toString(Interp.takeError())); return -1; }

  for (auto &src : sources) {
    std::string code = "#include \"" + src + "\"\n";
    if (auto E = (*Interp)->ParseAndExecute(code)) {
      setErr(err, errlen, llvm::toString(std::move(E)));
      return -1;
    }
  }

  auto Addr = (*Interp)->getSymbolAddress("main");
  if (!Addr) { setErr(err, errlen, "Không tìm thấy hàm main()."); llvm::consumeError(Addr.takeError()); return -1; }
  using MainFn = int (*)(int, char **);
  auto Main = Addr->toPtr<MainFn>();
  char arg0[] = "catnip";
  char *argv[] = {arg0, nullptr};
  int rc = Main(1, argv);
  std::fflush(nullptr);
  return rc;
}
