// Copyright (C) 2026 những người đóng góp 2oLang
// SPDX-License-Identifier: GPL-3.0-or-later
// Chương trình này là phần mềm tự do: bạn có thể phân phối lại và/hoặc sửa đổi nó theo các điều khoản của
// Giấy phép Công cộng GNU phiên bản 3 hoặc (tuỳ bạn chọn) bất kỳ phiên bản nào sau đó. Xem file LICENSE.
// Chương trình được phân phối với hy vọng hữu ích nhưng KHÔNG CÓ BẢO HÀNH NÀO.

// TwooLang compiler - bộ mã hoá lệnh x86 dùng chung cho i386 (W=4) và x86_64 (W=8)
// Chỉ dùng các thanh ghi cũ (eax..edi) nên bảng mã giống nhau, x86_64 thêm tiền tố REX.W.
#pragma once
#include <cstdint>
#include <stdexcept>
#include <vector>

enum Reg { EAX = 0, ECX = 1, EDX = 2, EBX = 3, ESP = 4, EBP = 5, ESI = 6, EDI = 7 };
enum Cond { CC_B = 2, CC_AE = 3, CC_E = 4, CC_NE = 5, CC_BE = 6, CC_A = 7, CC_P = 0xA, CC_L = 0xC, CC_GE = 0xD, CC_LE = 0xE, CC_G = 0xF };
enum Alu { A_ADD = 0, A_OR = 1, A_AND = 4, A_SUB = 5, A_XOR = 6, A_CMP = 7 };
enum Shift { S_SHL = 4, S_SHR = 5, S_SAR = 7 };

constexpr uint32_t HEAP_SENTINEL = 0xFFFFFFFFu;  // tham chiếu tới vùng heap zerofill (macOS)

// ---- A64 (iOS arm64): mô phỏng đúng ngữ nghĩa x86 ở trên ----
// Thanh ghi x86 -> A64: eax=x0 ecx=x1 edx=x2 ebx=x3 esi=x4 edi=x5; esp=x27 và ebp=x28 là NGĂN XẾP PHẦN MỀM
// (không dùng sp thật, vì sp phải căn 16 byte còn ở đây từ nguyên 8 byte). x16/x17 là thanh ghi tạm.
// call/ret đặt địa chỉ trả về lên ngăn xếp phần mềm y như x86 nên bố cục khung hàm giữ nguyên.
// Hàm hệ thống (đọc/ghi/ioctl/thoát/pow) đi qua con trỏ hàm của app, nằm ở ô runtime số 63.
constexpr uint32_t A64_HOST_CELL = 63 * 8;
static inline int A(int r) {
    static const int m[8] = {0, 1, 2, 3, 27, 28, 4, 5};
    return m[r];
}

struct Asm {
    bool a64 = false;
    int W;
    std::vector<uint8_t> code;
    std::vector<int> labelPos;
    struct Fix {
        size_t at;
        int label;
        int kind = 0;  // 0: rel32 (x86), 1: b imm26, 2: b.cond imm19
    };
    struct DFix {
        size_t at;
        uint32_t off;
    };
    std::vector<Fix> fixes;
    std::vector<DFix> dfixes;

    explicit Asm(int w, bool arm = false) : a64(arm), W(w) {}

    // ---- bộ mã hoá A64 ----
    void w32(uint32_t x) { d32(x); }
    static int acond(Cond c) {
        switch (c) {
            case CC_B: return 3;   // lo
            case CC_AE: return 2;  // hs
            case CC_E: return 0;
            case CC_NE: return 1;
            case CC_BE: return 9;  // ls
            case CC_A: return 8;   // hi
            case CC_P: return 6;   // vs (không so sánh được: NaN)
            case CC_L: return 11;
            case CC_GE: return 10;
            case CC_LE: return 13;
            case CC_G: return 12;
        }
        return 14;
    }
    void a_movRI(int rd, int64_t imm) {
        uint64_t v = (uint64_t)imm;
        int z = 0, o = 0;
        for (int i = 0; i < 4; i++) {
            uint16_t h = (v >> (16 * i)) & 0xFFFF;
            if (h == 0) z++;
            if (h == 0xFFFF) o++;
        }
        bool inv = o > z;
        uint64_t u = inv ? ~v : v;
        bool first = true;
        for (int i = 0; i < 4; i++) {
            uint16_t h = (u >> (16 * i)) & 0xFFFF;
            if (h == 0 && !(i == 3 && first)) continue;
            if (first) {
                w32((inv ? 0x92800000u : 0xD2800000u) | (i << 21) | (h << 5) | rd);
                first = false;
            } else {
                w32(0xF2800000u | (i << 21) | ((inv ? (uint16_t)~h : h) << 5) | rd);
            }
        }
        if (first) w32(0xD2800000u | rd);  // imm = 0
    }
    void a_mov(int rd, int rm) { w32(0xAA0003E0u | (rm << 16) | rd); }
    // truy cập bộ nhớ: size 8/4/1; load/store; reg là thanh ghi A64 (hoặc số d cho FP khi fp = true)
    void a_mem(bool ld, int bytes, bool fp, int rt, int rn, int32_t disp) {
        uint32_t uns, unscaled;
        if (fp) { uns = ld ? 0xFD400000u : 0xFD000000u; unscaled = ld ? 0xFC400000u : 0xFC000000u; }
        else if (bytes == 8) { uns = ld ? 0xF9400000u : 0xF9000000u; unscaled = ld ? 0xF8400000u : 0xF8000000u; }
        else if (bytes == 4) { uns = ld ? 0xB9400000u : 0xB9000000u; unscaled = ld ? 0xB8400000u : 0xB8000000u; }
        else { uns = ld ? 0x39400000u : 0x39000000u; unscaled = ld ? 0x38400000u : 0x38000000u; }
        int sc = fp ? 8 : bytes;
        if (disp >= 0 && disp % sc == 0 && disp / sc < 4096) {
            w32(uns | ((disp / sc) << 10) | (rn << 5) | rt);
        } else if (disp >= -256 && disp <= 255) {
            w32(unscaled | ((disp & 0x1FF) << 12) | (rn << 5) | rt);
        } else {
            a_movRI(16, disp);
            w32(0x8B000000u | (16 << 16) | (rn << 5) | 16);  // add x16, rn, x16
            w32(uns | (16 << 5) | rt);
        }
    }
    void a_addsubI(bool sub, int rd, int rn, int64_t imm) {  // rd = rn +/- imm (rd/rn không phải xzr)
        if (imm < 0) { sub = !sub; imm = -imm; }
        if (imm < 4096) {
            w32((sub ? 0xD1000000u : 0x91000000u) | ((uint32_t)imm << 10) | (rn << 5) | rd);
        } else {
            a_movRI(16, imm);
            w32((sub ? 0xCB000000u : 0x8B000000u) | (16 << 16) | (rn << 5) | rd);
        }
    }
    // gọi hàm của app: x0 = mã, x1..x3 = tham số; kết quả ở x0
    void hostCall() {
        leaData(16, A64_HOST_CELL);
        a_mem(true, 8, false, 16, 16, 0);
        w32(0xD63F0000u | (16 << 5));  // blr x16
    }
    // đầu chương trình: x0 = con trỏ hàm app, x1 = đỉnh ngăn xếp phần mềm
    void entryPrologue() {
        a_mov(27, 1);
        leaData(17, A64_HOST_CELL);
        a_mem(false, 8, false, 0, 17, 0);
    }

    // ---- byte thô ----
    void b(uint8_t x) { code.push_back(x); }
    void d32(uint32_t x) {
        for (int i = 0; i < 4; i++) b((x >> (8 * i)) & 0xFF);
    }
    void d64(uint64_t x) {
        for (int i = 0; i < 8; i++) b((x >> (8 * i)) & 0xFF);
    }
    void rex() {
        if (W == 8) b(0x48);
    }
    void modrmRR(int reg, int rm) { b(0xC0 | (reg << 3) | rm); }
    void modrmMem(int reg, int base, int32_t disp) {
        bool sib = (base == ESP);
        if (disp == 0 && base != EBP) {
            b((reg << 3) | base);
            if (sib) b(0x24);
        } else if (disp >= -128 && disp <= 127) {
            b(0x40 | (reg << 3) | base);
            if (sib) b(0x24);
            b((uint8_t)disp);
        } else {
            b(0x80 | (reg << 3) | base);
            if (sib) b(0x24);
            d32((uint32_t)disp);
        }
    }

    // ---- nhãn ----
    int newLabel() {
        labelPos.push_back(-1);
        return (int)labelPos.size() - 1;
    }
    void bind(int l) { labelPos[l] = (int)code.size(); }
    size_t pos() const { return code.size(); }
    void jmp(int l) {
        if (a64) { fixes.push_back({code.size(), l, 1}); w32(0x14000000u); return; }
        b(0xE9);
        fixes.push_back({code.size(), l});
        d32(0);
    }
    void jcc(Cond c, int l) {
        if (a64) { fixes.push_back({code.size(), l, 2}); w32(0x54000000u | acond(c)); return; }
        b(0x0F);
        b(0x80 | c);
        fixes.push_back({code.size(), l});
        d32(0);
    }
    void call(int l) {
        if (a64) {
            w32(0x10000000u | (3u << 5) | 16);                  // adr x16, .+12  (địa chỉ sau lệnh b)
            w32(0xF8000C00u | ((-8 & 0x1FF) << 12) | (27 << 5) | 16);  // str x16, [x27, #-8]!
            fixes.push_back({code.size(), l, 1});
            w32(0x14000000u);
            return;
        }
        b(0xE8);
        fixes.push_back({code.size(), l});
        d32(0);
    }
    void finalizeLabels() {
        for (auto& f : fixes) {
            if (labelPos[f.label] < 0) throw std::runtime_error("nhãn chưa được định nghĩa (lỗi nội bộ)");
            if (a64) {
                int64_t d = ((int64_t)labelPos[f.label] - (int64_t)f.at) / 4;
                uint32_t w = code[f.at] | (code[f.at + 1] << 8) | (code[f.at + 2] << 16) | ((uint32_t)code[f.at + 3] << 24);
                if (f.kind == 1) {
                    if (d < -(1 << 25) || d >= (1 << 25)) throw std::runtime_error("nhảy quá xa (lỗi nội bộ)");
                    w |= (uint32_t)d & 0x3FFFFFF;
                } else {
                    if (d < -(1 << 18) || d >= (1 << 18)) throw std::runtime_error("chương trình quá lớn cho nhảy điều kiện arm64");
                    w |= ((uint32_t)d & 0x7FFFF) << 5;
                }
                for (int i = 0; i < 4; i++) code[f.at + i] = (w >> (8 * i)) & 0xFF;
                continue;
            }
            int32_t rel = labelPos[f.label] - (int32_t)(f.at + 4);
            for (int i = 0; i < 4; i++) code[f.at + i] = (rel >> (8 * i)) & 0xFF;
        }
    }
    // codeAddr = địa chỉ ảo của byte đầu tiên của code, dataAddr = địa chỉ ảo vùng data
    void patchData(uint64_t codeAddr, uint64_t dataAddr, uint64_t heapAddr) {
        for (auto& f : dfixes) {
            if (a64) {
                uint64_t T = (f.off == HEAP_SENTINEL) ? heapAddr : dataAddr + f.off;
                uint64_t pc = codeAddr + f.at;
                int64_t pd = (int64_t)(T >> 12) - (int64_t)(pc >> 12);
                uint32_t w0 = code[f.at] | (code[f.at + 1] << 8) | (code[f.at + 2] << 16) | ((uint32_t)code[f.at + 3] << 24);
                uint32_t w1 = code[f.at + 4] | (code[f.at + 5] << 8) | (code[f.at + 6] << 16) | ((uint32_t)code[f.at + 7] << 24);
                w0 |= (((uint32_t)pd & 3) << 29) | ((((uint32_t)pd >> 2) & 0x7FFFF) << 5);
                w1 |= (uint32_t)(T & 0xFFF) << 10;
                for (int i = 0; i < 4; i++) { code[f.at + i] = (w0 >> (8 * i)) & 0xFF; code[f.at + 4 + i] = (w1 >> (8 * i)) & 0xFF; }
                continue;
            }
            uint64_t target = (f.off == HEAP_SENTINEL) ? heapAddr : dataAddr + f.off;
            uint64_t v = (W == 8) ? target - (codeAddr + f.at + 4) : target;
            for (int i = 0; i < 4; i++) code[f.at + i] = (v >> (8 * i)) & 0xFF;
        }
    }

    // ---- di chuyển dữ liệu ----
    void movRI(int r, int64_t imm) {
        if (a64) { a_movRI(A(r), imm); return; }
        if (W == 4) {
            b(0xB8 + r);
            d32((uint32_t)imm);
        } else if (imm >= INT32_MIN && imm <= INT32_MAX) {
            b(0x48);
            b(0xC7);
            modrmRR(0, r);
            d32((uint32_t)imm);
        } else {
            b(0x48);
            b(0xB8 + r);
            d64((uint64_t)imm);
        }
    }
    void movRR(int dst, int src) {
        if (dst == src) return;
        if (a64) { a_mov(A(dst), A(src)); return; }
        rex();
        b(0x89);
        modrmRR(src, dst);
    }
    void load(int r, int base, int32_t disp) {
        if (a64) { a_mem(true, 8, false, A(r), A(base), disp); return; }
        rex();
        b(0x8B);
        modrmMem(r, base, disp);
    }
    void store(int base, int32_t disp, int r) {
        if (a64) { a_mem(false, 8, false, A(r), A(base), disp); return; }
        rex();
        b(0x89);
        modrmMem(r, base, disp);
    }
    void load32(int r, int base, int32_t disp) {  // mov r32, [m]  (64-bit: xoá nửa cao)
        if (a64) { a_mem(true, 4, false, A(r), A(base), disp); return; }
        b(0x8B);
        modrmMem(r, base, disp);
    }
    void store32(int base, int32_t disp, int r) {
        if (a64) { a_mem(false, 4, false, A(r), A(base), disp); return; }
        b(0x89);
        modrmMem(r, base, disp);
    }
    void load8(int r, int base, int32_t disp) {  // movzx r32, byte [m]
        if (a64) { a_mem(true, 1, false, A(r), A(base), disp); return; }
        b(0x0F);
        b(0xB6);
        modrmMem(r, base, disp);
    }
    void store8(int base, int32_t disp, int r) {  // r phải là eax/ecx/edx/ebx
        if (a64) { a_mem(false, 1, false, A(r), A(base), disp); return; }
        b(0x88);
        modrmMem(r, base, disp);
    }
    void lea(int r, int base, int32_t disp) {
        if (a64) { a_addsubI(false, A(r), A(base), disp); return; }
        rex();
        b(0x8D);
        modrmMem(r, base, disp);
    }
    // r = địa chỉ vùng data + off
    void leaData(int r, uint32_t off) {
        if (a64) {
            int x = (r >= 8) ? r : A(r);  // r >= 8: số thanh ghi A64 thô (x16, x17)
            dfixes.push_back({code.size(), off});
            w32(0x90000000u | x);                    // adrp x, #0
            w32(0x91000000u | (x << 5) | x);          // add x, x, #0
            return;
        }
        if (W == 8) {
            b(0x48);
            b(0x8D);
            b((r << 3) | 0x05);  // [rip+disp32]
        } else {
            b(0xB8 + r);
        }
        dfixes.push_back({code.size(), off});
        d32(0);
    }

    // ---- số học ----
    void alu(Alu op, int dst, int src) {
        if (a64) {
            int d = A(dst), m = A(src);
            switch (op) {
                case A_ADD: w32(0x8B000000u | (m << 16) | (d << 5) | d); break;
                case A_SUB: w32(0xCB000000u | (m << 16) | (d << 5) | d); break;
                case A_AND: w32(0x8A000000u | (m << 16) | (d << 5) | d); break;
                case A_OR: w32(0xAA000000u | (m << 16) | (d << 5) | d); break;
                case A_XOR: w32(0xCA000000u | (m << 16) | (d << 5) | d); break;
                case A_CMP: w32(0xEB00001Fu | (m << 16) | (d << 5)); break;  // subs xzr, d, m
            }
            return;
        }
        rex();
        b((op << 3) | 1);
        modrmRR(src, dst);
    }
    void aluI(Alu op, int r, int32_t imm) {
        if (a64) {
            int d = A(r);
            if (op == A_ADD) a_addsubI(false, d, d, imm);
            else if (op == A_SUB) a_addsubI(true, d, d, imm);
            else if (op == A_CMP) {
                if (imm >= 0 && imm < 4096) w32(0xF100001Fu | ((uint32_t)imm << 10) | (d << 5));
                else { a_movRI(16, imm); w32(0xEB00001Fu | (16 << 16) | (d << 5)); }
            } else {
                a_movRI(16, imm);
                uint32_t base = op == A_AND ? 0x8A000000u : op == A_OR ? 0xAA000000u : 0xCA000000u;
                w32(base | (16 << 16) | (d << 5) | d);
            }
            return;
        }
        rex();
        if (imm >= -128 && imm <= 127) {
            b(0x83);
            modrmRR(op, r);
            b((uint8_t)imm);
        } else {
            b(0x81);
            modrmRR(op, r);
            d32((uint32_t)imm);
        }
    }
    void imul(int dst, int src) {
        if (a64) { int d = A(dst), m = A(src); w32(0x9B007C00u | (m << 16) | (d << 5) | d); return; }
        rex();
        b(0x0F);
        b(0xAF);
        modrmRR(dst, src);
    }
    void neg(int r) {
        if (a64) { w32(0xCB0003E0u | (A(r) << 16) | A(r)); return; }
        rex(); b(0xF7); modrmRR(3, r);
    }
    void notr(int r) {
        if (a64) { w32(0xAA2003E0u | (A(r) << 16) | A(r)); return; }
        rex(); b(0xF7); modrmRR(2, r);
    }
    // x86: edx:eax / r -> eax = thương, edx = dư. A64: cdq không làm gì, idiv tính cả hai.
    void idiv(int r) {
        if (a64) {
            int m = A(r);
            w32(0x9AC00C00u | (m << 16) | (0 << 5) | 16);          // sdiv x16, x0, m
            w32(0x9B008000u | (m << 16) | (0 << 10) | (16 << 5) | 2);  // msub x2, x16, m, x0
            w32(0xAA0003E0u | (16 << 16) | 0);                      // mov x0, x16
            return;
        }
        rex(); b(0xF7); modrmRR(7, r);
    }
    void cdq() { if (a64) return; rex(); b(0x99); }  // cdq / cqo
    void shiftCL(Shift s, int r) {
        if (a64) {
            uint32_t base = s == S_SHL ? 0x9AC02000u : s == S_SHR ? 0x9AC02400u : 0x9AC02800u;
            w32(base | (1 << 16) | (A(r) << 5) | A(r));  // lslv/lsrv/asrv r, r, x1(ecx)
            return;
        }
        rex(); b(0xD3); modrmRR(s, r);
    }
    void test(int a, int c) {
        if (a64) { w32(0xEA00001Fu | (A(c) << 16) | (A(a) << 5)); return; }
        rex(); b(0x85); modrmRR(c, a);
    }
    void setcc(Cond c) {  // set<c> al
        if (a64) { w32(0x9A9F07E0u | ((acond(c) ^ 1) << 12) | 0); return; }  // cset x0, c
        b(0x0F); b(0x90 | c); b(0xC0);
    }
    void movzxAl() { if (a64) return; b(0x0F); b(0xB6); b(0xC0); }  // movzx eax, al

    // ---- ngăn xếp / điều khiển ----
    void push(int r) {
        if (a64) { w32(0xF8000C00u | ((-8 & 0x1FF) << 12) | (27 << 5) | A(r)); return; }  // str r, [x27, #-8]!
        b(0x50 + r);
    }
    void pop(int r) {
        if (a64) { w32(0xF8400400u | ((8 & 0x1FF) << 12) | (27 << 5) | A(r)); return; }  // ldr r, [x27], #8
        b(0x58 + r);
    }
    void pushI(int32_t imm) {
        if (a64) { a_movRI(17, imm); w32(0xF8000C00u | ((-8 & 0x1FF) << 12) | (27 << 5) | 17); return; }
        b(0x68); d32((uint32_t)imm);
    }
    void ret() {
        if (a64) {
            w32(0xF8400400u | ((8 & 0x1FF) << 12) | (27 << 5) | 16);  // ldr x16, [x27], #8
            w32(0xD61F0000u | (16 << 5));                              // br x16
            return;
        }
        b(0xC3);
    }
    void syscall64() { b(0x0F); b(0x05); }
    void int80() { b(0xCD); b(0x80); }
    void rdtsc() {
        if (a64) { w32(0xD53BE040u); w32(0x2A0003E0u); return; }  // mrs x0, cntvct_el0 ; mov w0, w0
        b(0x0F); b(0x31);
    }

    // ---- SSE2 (double, thao tác trên bộ nhớ) ----
    // op: 0x10 movsd load, 0x11 movsd store, 0x58 add, 0x59 mul, 0x5C sub, 0x5E div
    void sd(uint8_t op, int base) {
        if (a64) {
            int n = A(base);
            if (op == 0x10) { a_mem(true, 8, true, 0, n, 0); return; }
            if (op == 0x11) { a_mem(false, 8, true, 0, n, 0); return; }
            a_mem(true, 8, true, 1, n, 0);  // d1 = [base]
            uint32_t o = op == 0x58 ? 0x1E612800u : op == 0x5C ? 0x1E613800u : op == 0x59 ? 0x1E610800u : 0x1E611800u;
            w32(o);  // f<op> d0, d0, d1
            return;
        }
        b(0xF2); b(0x0F); b(op); modrmMem(0, base, 0); }
    void ucomisd(int base) {
        if (a64) { a_mem(true, 8, true, 1, A(base), 0); w32(0x1E612000u); return; }  // ldr d1,[base]; fcmp d0, d1
        b(0x66); b(0x0F); b(0x2E); modrmMem(0, base, 0); }
    void cvtsi2sd(int r) {
        if (a64) { w32(0x9E620000u | (A(r) << 5)); return; }  // scvtf d0, xr
        b(0xF2); rex(); b(0x0F); b(0x2A); modrmRR(0, r); }       // xmm0 = (double)r
    void cvttsd2si(int r, int base) {
        if (a64) { a_mem(true, 8, true, 1, A(base), 0); w32(0x9E780020u | A(r)); return; }  // ldr d1,[base]; fcvtzs xr, d1
        b(0xF2); rex(); b(0x0F); b(0x2C); modrmMem(r, base, 0); }  // r = (word)[base]

    // ---- x87 ----
    // *edx = round(*ecx) theo chế độ mode (0 gần nhất, 1 xuống, 2 lên, 3 cắt phần lẻ); dùng eax làm tạm
    void fround(int mode) {
        if (a64) {
            a_mem(true, 8, true, 0, A(ECX), 0);
            static const uint32_t ops[] = {0x1E644000u, 0x1E654000u, 0x1E64C000u, 0x1E65C000u};  // frintn/m/p/z d0, d0
            w32(ops[mode & 3]);
            a_mem(false, 8, true, 0, A(EDX), 0);
            return;
        }
        aluI(A_SUB, ESP, 8);
        b(0xD9); modrmMem(7, ESP, 0);                 // fnstcw [esp]
        b(0x0F); b(0xB7); modrmMem(EAX, ESP, 0);      // movzx eax, word [esp]
        aluI(A_AND, EAX, 0xF3FF);
        aluI(A_OR, EAX, mode << 10);
        b(0x66); b(0x89); modrmMem(EAX, ESP, 2);      // mov [esp+2], ax
        b(0xD9); modrmMem(5, ESP, 2);                 // fldcw [esp+2]
        b(0xDD); modrmMem(0, ECX, 0);                 // fld qword [ecx]
        b(0xD9); b(0xFC);                             // frndint
        b(0xDD); modrmMem(3, EDX, 0);                 // fstp qword [edx]
        b(0xD9); modrmMem(5, ESP, 0);                 // fldcw [esp]
        aluI(A_ADD, ESP, 8);
    }
    // *edx = (*eax) ^ (*ecx) với số mũ thực
    void fpow() {
        if (a64) {  // nhờ app: mã 100, x1 = &x, x2 = &y, x3 = &kết quả
            a_mov(17, 0);  // x17 = eax (&x)
            a_mov(3, 2);   // x3 = edx (đích)
            a_mov(2, 1);   // x2 = ecx (&y)
            a_mov(1, 17);
            a_movRI(0, 100);
            hostCall();
            return;
        }
        b(0xDD); modrmMem(0, ECX, 0);  // fld y
        b(0xDD); modrmMem(0, EAX, 0);  // fld x
        b(0xD9); b(0xF1);              // fyl2x
        b(0xD9); b(0xC0);              // fld st0
        b(0xD9); b(0xFC);              // frndint
        b(0xDC); b(0xE9);              // fsub st1, st0
        b(0xD9); b(0xC9);              // fxch st1
        b(0xD9); b(0xF0);              // f2xm1
        b(0xD9); b(0xE8);              // fld1
        b(0xDE); b(0xC1);              // faddp st1, st0
        b(0xD9); b(0xFD);              // fscale
        b(0xDD); b(0xD9);              // fstp st1
        b(0xDD); modrmMem(3, EDX, 0);  // fstp qword [edx]
    }
};
