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

#include <dlfcn.h>
#include <cstdint>
#include <csignal>
#include <cstdlib>
#include <cstdio>
#include <execinfo.h>
#include <fcntl.h>
#include <unistd.h>
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

// Nhật ký từng bước ghi thẳng vào file (không qua stdio) để còn đọc được khi app sập; xem trong app Tệp:
// Catnip/catnip-clang-trace.log (thư mục Documents của app). Khi nhận SIGSEGV/SIGABRT/SIGBUS/SIGILL cũng ghi tên tín hiệu và backtrace.
static int gTraceFd = -1;

static void trace(const char *msg) {
  if (gTraceFd < 0) return;
  (void)!write(gTraceFd, msg, strlen(msg));
  (void)!write(gTraceFd, "\n", 1);
  fsync(gTraceFd);
}

static void crashHandler(int sig) {
  char buf[64];
  int n = std::snprintf(buf, sizeof buf, "!!! TIN HIEU %d\n", sig);
  if (gTraceFd >= 0) {
    (void)!write(gTraceFd, buf, (size_t)n);
    void *frames[48];
    int cnt = backtrace(frames, 48);
    backtrace_symbols_fd(frames, cnt, gTraceFd);
    fsync(gTraceFd);
  }
  signal(sig, SIG_DFL);
  raise(sig);
}

// iOS chỉ cho chạy mã sinh lúc chạy (JIT) khi tiến trình có cờ CS_DEBUGGED; thiếu thì kernel SIGKILL ngay
// khi nhảy vào trang nhớ chưa ký (không bắt được tín hiệu). Với TrollStore (có get-task-allow) gọi
// ptrace(PT_TRACE_ME) để kernel bật cờ này, giống các app emulator/JIT.
extern "C" int csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize);
static bool ensureJIT() {
  const unsigned CS_DEBUGGED = 0x10000000;
  auto flags = []() { uint32_t f = 0; csops(getpid(), 0 /*CS_OPS_STATUS*/, &f, sizeof f); return f; };
  uint32_t f = flags();
  char b[96];
  std::snprintf(b, sizeof b, "    csops flags truoc = 0x%x (CS_DEBUGGED=%d)", f, (f & CS_DEBUGGED) ? 1 : 0);
  trace(b);
  if (f & CS_DEBUGGED) return true;
  using PtraceFn = int (*)(int, pid_t, void *, int);
  auto pt = (PtraceFn)dlsym(RTLD_DEFAULT, "ptrace");
  if (pt) { int r = pt(0 /*PT_TRACE_ME*/, 0, nullptr, 0); std::snprintf(b, sizeof b, "    ptrace(PT_TRACE_ME) = %d", r); trace(b); }
  else trace("    khong tim thay ptrace");
  f = flags();
  std::snprintf(b, sizeof b, "    csops flags sau = 0x%x (CS_DEBUGGED=%d)", f, (f & CS_DEBUGGED) ? 1 : 0);
  trace(b);
  return (f & CS_DEBUGGED) != 0;
}

static void setErr(char *err, int errlen, const std::string &msg) {
  if (!err || errlen <= 0) return;
  std::snprintf(err, (size_t)errlen, "%s", msg.c_str());
}

extern "C" __attribute__((visibility("default")))
int catnip_clang_run(const char *resource_dir, const char *sysroot, const char *flags_nl,
                     const char *sources_nl, char *err, int errlen) {
  {
    const char *home = getenv("HOME");
    std::string path = std::string(home ? home : ".") + "/Documents/catnip-clang-trace.log";
    gTraceFd = open(path.c_str(), O_WRONLY | O_CREAT | O_TRUNC, 0644);
    for (int sg : {SIGSEGV, SIGABRT, SIGBUS, SIGILL, SIGTRAP}) signal(sg, crashHandler);
    trace("[1] catnip_clang_run bat dau");
  }
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
  trace("[2] chuan bi tao CompilerInstance");
  clang::IncrementalCompilerBuilder CB;     // chỉ để dựng CompilerInstance C++ đã cấu hình sẵn (driver, target, diagnostics)
  CB.SetCompilerArgs(args);

  trace("[3] tao LLJIT");
  auto JIT = llvm::orc::LLJITBuilder().create();
  if (!JIT) { setErr(err, errlen, llvm::toString(JIT.takeError())); return -1; }
  auto &JD = (*JIT)->getMainJITDylib();
  auto Gen = llvm::orc::DynamicLibrarySearchGenerator::GetForCurrentProcess((*JIT)->getDataLayout().getGlobalPrefix());
  if (!Gen) { setErr(err, errlen, llvm::toString(Gen.takeError())); return -1; }
  JD.addGenerator(std::move(*Gen));

  for (auto &src : sources) {
    trace(("[4] CreateCpp cho " + src).c_str());
    auto CI = CB.CreateCpp();
    if (!CI) { setErr(err, errlen, llvm::toString(CI.takeError())); return -1; }
    // CreateCpp bật -fincremental-extensions (dành cho clang-repl): parser coi mọi thứ không nhận ra là "top-level statement"
    // và Sema abort/crash. Ta biên dịch cả file như bình thường nên tắt đi (lỗi thật sẽ hiện thành chẩn đoán).
    (*CI)->getLangOpts().IncrementalExtensions = false;
    auto &FOpts = (*CI)->getFrontendOpts();
    FOpts.Inputs.clear();
    FOpts.Inputs.push_back(clang::FrontendInputFile(src, clang::Language::CXX));
    auto Ctx = std::make_unique<llvm::LLVMContext>();
    std::unique_ptr<llvm::Module> Mod;
    {
      trace("[5] ExecuteAction (parse + sinh IR)");
      clang::EmitLLVMOnlyAction Act(Ctx.get());
      if (!(*CI)->ExecuteAction(Act)) { setErr(err, errlen, "Biên dịch lỗi: " + src); return -1; }
      Mod = Act.takeModule();
    }
    trace("[6] da sinh IR, them vao JIT");
    if (!Mod) { setErr(err, errlen, "Không sinh được module cho " + src); return -1; }
    if (auto E = (*JIT)->addIRModule(llvm::orc::ThreadSafeModule(std::move(Mod), std::move(Ctx)))) {
      setErr(err, errlen, llvm::toString(std::move(E)));
      return -1;
    }
  }

  trace("[7] initialize + lookup main");
  if (auto E = (*JIT)->initialize(JD)) { setErr(err, errlen, llvm::toString(std::move(E))); return -1; }
  auto Addr = (*JIT)->lookup("main");
  if (!Addr) { setErr(err, errlen, "Không tìm thấy hàm main(): " + llvm::toString(Addr.takeError())); return -1; }
  using MainFn = int (*)(int, char **);
  auto Main = Addr->toPtr<MainFn>();
  char arg0[] = "catnip";
  char *argv[] = {arg0, nullptr};
  if (!ensureJIT()) {
    setErr(err, errlen, "Tiến trình chưa có quyền JIT (CS_DEBUGGED). Cần cài bằng TrollStore (kèm get-task-allow) hoặc bật JIT qua SideStore/StikDebug rồi chạy lại.");
    return -1;
  }
  trace("[8] goi main()");
  int rc = Main(1, argv);
  trace("[9] main() xong");
  std::fflush(nullptr);
  // KHÔNG deinitialize/giải phóng JIT: hàm huỷ (atexit) do mã JIT đăng ký (iostream...) có thể còn
  // trỏ vào vùng nhớ JIT; giải phóng rồi mà host gọi lại sẽ sập cả app. Chấp nhận rò rỉ vùng nhớ nhỏ.
  (void)(*JIT).release();
  trace("[10] xong, tra ve");
  return rc;
}
