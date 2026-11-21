// libcatnipclang: bọc Clang Interpreter (clang-repl) + ORC JIT thành API C cho Catnip.
// Biên dịch kèm LLVM/Clang (xem tools/build_clang_pack.sh). Chưa build/kiểm chứng; viết theo LLVM 20.
//
//   int catnip_clang_run(const char *resource_dir, const char *sysroot,
//                        const char *flags_nl, const char *sources_nl, char *err, int errlen);
// flags_nl / sources_nl: danh sách phân tách bằng '\n'. Trả về mã thoát của main(), hoặc -1 nếu lỗi (err có mô tả).

#include "clang/CodeGen/CodeGenAction.h"
#include "clang/Frontend/CompilerInstance.h"
#include "clang/Frontend/FrontendOptions.h"
#include "clang/Interpreter/Interpreter.h"
#include "llvm/ExecutionEngine/Orc/Core.h"
#include "llvm/ExecutionEngine/Orc/ExecutionUtils.h"
#include "llvm/ExecutionEngine/Orc/LLJIT.h"
#include "llvm/ExecutionEngine/Orc/ThreadSafeModule.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Module.h"
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
  args.push_back("-fno-exceptions");
  for (auto &f : flagStrs) args.push_back(f.c_str());

  // Không dùng clang::Interpreter (clang-repl bị crash null CurContext trong Sema trên iOS):
  // biên dịch từng file bằng CompilerInstance + EmitLLVMOnlyAction rồi nạp vào LLJIT.
  clang::IncrementalCompilerBuilder CB;     // chỉ để dựng CompilerInstance C++ đã cấu hình sẵn (driver, target, diagnostics)
  CB.SetCompilerArgs(args);

  auto JIT = llvm::orc::LLJITBuilder().create();
  if (!JIT) { setErr(err, errlen, llvm::toString(JIT.takeError())); return -1; }
  auto &JD = (*JIT)->getMainJITDylib();
  auto Gen = llvm::orc::DynamicLibrarySearchGenerator::GetForCurrentProcess((*JIT)->getDataLayout().getGlobalPrefix());
  if (!Gen) { setErr(err, errlen, llvm::toString(Gen.takeError())); return -1; }
  JD.addGenerator(std::move(*Gen));

  for (auto &src : sources) {
    auto CI = CB.CreateCpp();
    if (!CI) { setErr(err, errlen, llvm::toString(CI.takeError())); return -1; }
    auto &FOpts = (*CI)->getFrontendOpts();
    FOpts.Inputs.clear();
    FOpts.Inputs.push_back(clang::FrontendInputFile(src, clang::Language::CXX));
    auto Ctx = std::make_unique<llvm::LLVMContext>();
    std::unique_ptr<llvm::Module> Mod;
    {
      clang::EmitLLVMOnlyAction Act(Ctx.get());
      if (!(*CI)->ExecuteAction(Act)) { setErr(err, errlen, "Biên dịch lỗi: " + src); return -1; }
      Mod = Act.takeModule();
    }
    if (!Mod) { setErr(err, errlen, "Không sinh được module cho " + src); return -1; }
    if (auto E = (*JIT)->addIRModule(llvm::orc::ThreadSafeModule(std::move(Mod), std::move(Ctx)))) {
      setErr(err, errlen, llvm::toString(std::move(E)));
      return -1;
    }
  }

  if (auto E = (*JIT)->initialize(JD)) { setErr(err, errlen, llvm::toString(std::move(E))); return -1; }
  auto Addr = (*JIT)->lookup("main");
  if (!Addr) { setErr(err, errlen, "Không tìm thấy hàm main(): " + llvm::toString(Addr.takeError())); return -1; }
  using MainFn = int (*)(int, char **);
  auto Main = Addr->toPtr<MainFn>();
  char arg0[] = "catnip";
  char *argv[] = {arg0, nullptr};
  int rc = Main(1, argv);
  std::fflush(nullptr);
  (void)(*JIT)->deinitialize(JD);
  return rc;
}
