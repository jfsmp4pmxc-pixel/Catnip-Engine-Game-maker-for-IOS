// TwooBridge.cpp — nhúng trình biên dịch 2oLang và chạy ảnh iOS64 (arm64) ngay trong tiến trình app.
//
// Ảnh do backend A64 của 2oLang sinh ra (xem TwooLang/asm.hpp): [tiêu đề 32 byte][code][đệm][data]. Ở đây:
//   1. mmap một vùng (code + data + heap 256 MB zero-fill), chép code/data vào, đặt code thành RX.
//      iOS chỉ cho chạy mã sinh lúc chạy khi tiến trình có cờ CS_DEBUGGED (TrollStore + get-task-allow):
//      xin cờ bằng ptrace(PT_TRACE_ME), giống đường JIT của Clang++ (CppEngine).
//   2. Chương trình 2oLang không dùng syscall thật: mọi đọc/ghi/ioctl/thoát/pow đi qua hostSys() này.
//   3. exit → longjmp về chỗ gọi (khung duy nhất giữa hai bên là mã JIT, không có hàm huỷ C++ nào bị bỏ qua).
#include "../TwooBridge.h"

#include <cerrno>
#include <cmath>
#include <csetjmp>
#include <cstdio>
#include <cstring>
#include <dlfcn.h>
#include <fcntl.h>
#include <string>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <unistd.h>
#include <vector>
#if __has_include(<libkern/OSCacheControl.h>)
#include <libkern/OSCacheControl.h>
#define HAVE_ICACHE 1
#endif

int twoo_main(int argc, char **argv);  // TwooLang/main.cpp

extern "C" int csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize);

namespace {

jmp_buf g_exitJmp;
int g_exitCode = 0;
bool g_tty = false;
int g_rows = 24, g_cols = 80;

bool ensureJIT(std::string &why) {
    const uint32_t CS_DEBUGGED = 0x10000000;
    uint32_t f = 0;
    csops(getpid(), 0, &f, sizeof f);
    if (f & CS_DEBUGGED) return true;
    using PtraceFn = int (*)(int, pid_t, void *, int);
    auto pt = (PtraceFn)dlsym(RTLD_DEFAULT, "ptrace");
    if (pt) pt(0 /*PT_TRACE_ME*/, 0, nullptr, 0);
    f = 0;
    csops(getpid(), 0, &f, sizeof f);
    if (f & CS_DEBUGGED) return true;
    why = "Tiến trình chưa có quyền JIT (CS_DEBUGGED). Cần cài app bằng TrollStore (có get-task-allow) "
          "hoặc bật JIT qua SideStore/StikDebug rồi chạy lại.";
    return false;
}

// Mã gọi từ chương trình 2oLang: 0 đọc, 1 ghi, 2 thoát, 3 ioctl, 100 pow. Trả -errno khi lỗi (như syscall Linux).
extern "C" int64_t twoo_host_sys(int64_t no, int64_t a, int64_t b, int64_t c) {
    switch (no) {
        case 0: {
            ssize_t n;
            do { n = read((int)a, (void *)b, (size_t)c); } while (n < 0 && errno == EINTR);
            return n < 0 ? -errno : n;
        }
        case 1: {
            ssize_t n;
            do { n = write((int)a, (const void *)b, (size_t)c); } while (n < 0 && errno == EINTR);
            return n < 0 ? -errno : n;
        }
        case 2:
            g_exitCode = (int)a;
            longjmp(g_exitJmp, 1);
        case 3: {
            unsigned long req = (unsigned long)(uint32_t)b;
            if (g_tty && a == 1) {
                // Giả lập terminal ở stdout: lấy termios thành công (struct toàn 0), báo kích thước cửa sổ.
                // Hằng số Darwin (iOS): TIOCGETA, TIOCSETA, TIOCGWINSZ; struct termios dài 72 byte, winsize 8 byte.
                if (req == 0x40487413ul) { memset((void *)c, 0, 72); return 0; }
                if (req == 0x80487414ul) return 0;
                if (req == 0x40087468ul) {
                    uint16_t *w = (uint16_t *)c;
                    w[0] = (uint16_t)g_rows; w[1] = (uint16_t)g_cols; w[2] = 0; w[3] = 0;
                    return 0;
                }
            }
            int r = ioctl((int)a, req, (void *)c);
            return r < 0 ? -errno : r;
        }
        case 100: {
            double x, y;
            memcpy(&x, (const void *)a, 8);
            memcpy(&y, (const void *)b, 8);
            double r = pow(x, y);
            memcpy((void *)c, &r, 8);
            return 0;
        }
    }
    return -ENOSYS;
}

uint32_t rd32(const uint8_t *p) { return p[0] | (p[1] << 8) | (p[2] << 16) | ((uint32_t)p[3] << 24); }

}  // namespace

extern "C" void twoo_set_terminal(int enabled, int rows, int cols) {
    g_tty = enabled != 0;
    if (rows > 0) g_rows = rows;
    if (cols > 0) g_cols = cols;
}

extern "C" int twoo_compile(const char *input, const char *output, const char *userLibDir) {
    if (userLibDir && *userLibDir) setenv("TWOO_HOME", (std::string(userLibDir) + "/..").c_str(), 1);
    std::vector<std::string> args = {"2oLang", input, "-t", "iOS64", "-o", output, "--quiet"};
    if (userLibDir && *userLibDir) {
        args.push_back("-L");
        args.push_back(userLibDir);
    }
    std::vector<char *> argv;
    for (auto &s : args) argv.push_back(const_cast<char *>(s.c_str()));
    argv.push_back(nullptr);
    return twoo_main((int)args.size(), argv.data());
}

extern "C" int twoo_run_image(const char *path) {
    FILE *f = fopen(path, "rb");
    if (!f) { fprintf(stderr, "Không mở được ảnh: %s\n", path); return -1; }
    std::vector<uint8_t> img;
    uint8_t buf[65536];
    size_t n;
    while ((n = fread(buf, 1, sizeof buf, f)) > 0) img.insert(img.end(), buf, buf + n);
    fclose(f);
    if (img.size() < 32 || rd32(img.data()) != 0x36416F32) { fprintf(stderr, "Ảnh không đúng định dạng iOS64.\n"); return -1; }
    uint32_t codeOff = rd32(&img[4]), codeSize = rd32(&img[8]), dataOff = rd32(&img[12]), dataSize = rd32(&img[16]), heapSize = rd32(&img[20]);
    const size_t page = 16384;
    auto up = [&](size_t v) { return (v + page - 1) / page * page; };
    size_t codeSpan = dataOff;  // [0, dataOff) là tiêu đề + code (căn trang)
    size_t total = dataOff + up(dataSize) + heapSize;
    if (codeOff + codeSize > img.size() || dataOff + dataSize > img.size() || codeSpan % page) {
        fprintf(stderr, "Ảnh hỏng.\n");
        return -1;
    }
    std::string why;
    if (!ensureJIT(why)) { fprintf(stderr, "%s\n", why.c_str()); return -1; }

    void *base = mmap(nullptr, total, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0);
    if (base == MAP_FAILED) { fprintf(stderr, "Không cấp được bộ nhớ (%zu MB): %s\n", total >> 20, strerror(errno)); return -1; }
    const size_t stackSize = 16u << 20;
    void *stk = mmap(nullptr, stackSize, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0);
    if (stk == MAP_FAILED) { munmap(base, total); fprintf(stderr, "Không cấp được ngăn xếp.\n"); return -1; }
    memcpy(base, img.data(), codeOff + codeSize);
    memcpy((uint8_t *)base + dataOff, img.data() + dataOff, dataSize);
#ifdef HAVE_ICACHE
    sys_icache_invalidate(base, codeSpan);
#endif
    if (mprotect(base, codeSpan, PROT_READ | PROT_EXEC) != 0) {
        fprintf(stderr, "Không đặt được quyền thực thi cho mã (mprotect: %s). iOS chặn JIT với tiến trình này.\n", strerror(errno));
        munmap(base, total);
        munmap(stk, stackSize);
        return -1;
    }

    using EntryFn = void (*)(void *host, uint64_t stackTop);
    EntryFn entry = (EntryFn)((uint8_t *)base + codeOff);
    int rc;
    if (setjmp(g_exitJmp) == 0) {
        entry((void *)&twoo_host_sys, (uint64_t)stk + stackSize);
        rc = 0;  // không tới được: chương trình luôn kết thúc bằng exit
    } else {
        rc = g_exitCode;
    }
    fflush(nullptr);
    mprotect(base, codeSpan, PROT_READ | PROT_WRITE);
    munmap(base, total);
    munmap(stk, stackSize);
    return rc;
}
