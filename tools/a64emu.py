#!/usr/bin/env python3
"""Trình mô phỏng tối giản A64 (đúng tập lệnh mà backend iOS64 của 2oLang sinh ra) để kiểm thử trên máy x86.
Dùng:  a64emu.py <ảnh.bin> [stdin-file]   -> in stdout của chương trình, trả mã thoát.
Chỉ để kiểm tra backend (không có máy arm64 ở môi trường dev)."""
import math, struct, sys

M64 = (1 << 64) - 1
HOST = 0x7FFF0000
STACK_TOP = 0x30000000


class Mem:
    def __init__(self):
        self.pages = {}

    def page(self, a):
        p = self.pages.get(a >> 12)
        if p is None:
            p = bytearray(4096)
            self.pages[a >> 12] = p
        return p

    def rd(self, a, n):
        out = bytearray()
        for i in range(n):
            ad = a + i
            out.append(self.page(ad)[ad & 4095])
        return bytes(out)

    def wr(self, a, data):
        for i, b in enumerate(data):
            ad = a + i
            self.page(ad)[ad & 4095] = b

    def r64(self, a): return struct.unpack('<Q', self.rd(a, 8))[0]
    def r32(self, a): return struct.unpack('<I', self.rd(a, 4))[0]
    def r8(self, a): return self.rd(a, 1)[0]
    def w64(self, a, v): self.wr(a, struct.pack('<Q', v & M64))
    def w32(self, a, v): self.wr(a, struct.pack('<I', v & 0xFFFFFFFF))
    def w8(self, a, v): self.wr(a, bytes([v & 255]))


def sx(v, bits):
    return v - (1 << bits) if v >> (bits - 1) else v


def run(img, stdin=b''):
    mem = Mem()
    mem.wr(0, img)
    magic, codeOff, codeSize, dataOff, dataSize, heapSize = struct.unpack('<6I', img[:24])
    assert magic == 0x36416F32
    x = [0] * 32  # x[31] dùng làm xzr (luôn 0 khi đọc)
    d = [0.0] * 32
    N = Z = C = V = 0
    pc = codeOff
    x[0] = HOST
    x[1] = STACK_TOP
    out = bytearray()
    inp = bytearray(stdin)
    steps = 0

    def reg(n): return 0 if n == 31 else x[n]

    def setreg(n, v):
        if n != 31: x[n] = v & M64

    def addsub(a, b, sub, setf):
        nonlocal N, Z, C, V
        if sub:
            r = (a - b) & M64
            C = 1 if a >= b else 0
            V = 1 if (sx(a, 64) - sx(b, 64)) != sx(r, 64) else 0
        else:
            r = (a + b) & M64
            C = 1 if (a + b) > M64 else 0
            V = 1 if (sx(a, 64) + sx(b, 64)) != sx(r, 64) else 0
        if setf:
            N = r >> 63
            Z = 1 if r == 0 else 0
        return r

    def cond(c):
        base = c >> 1
        if base == 0: r = Z == 1
        elif base == 1: r = C == 1
        elif base == 2: r = N == 1
        elif base == 3: r = V == 1
        elif base == 4: r = C == 1 and Z == 0
        elif base == 5: r = N == V
        elif base == 6: r = N == V and Z == 0
        else: r = True
        if (c & 1) and c != 15: r = not r
        return r

    def host(no, a, b, c):
        nonlocal inp
        if no == 0:  # read
            n = min(c, len(inp))
            mem.wr(b, bytes(inp[:n]))
            del inp[:n]
            return n
        if no == 1:
            data = mem.rd(b, c)
            if a in (1, 2): out.extend(data)
            return c
        if no == 2:
            raise SystemExit(a & 255)
        if no == 3:
            return (-25) & M64  # ENOTTY
        if no == 100:
            xv = struct.unpack('<d', mem.rd(a, 8))[0]
            yv = struct.unpack('<d', mem.rd(b, 8))[0]
            try:
                r = math.pow(xv, yv)
            except OverflowError:
                r = math.inf
            except ValueError:
                r = math.nan
            mem.wr(c, struct.pack('<d', r))
            return 0
        raise RuntimeError('host no=%d' % no)

    try:
        while True:
            steps += 1
            if steps > 400_000_000: raise RuntimeError('quá nhiều bước')
            w = struct.unpack_from('<I', img, pc)[0] if pc < len(img) else None
            if w is None: raise RuntimeError('pc ngoài ảnh %x' % pc)
            npc = pc + 4
            rd = w & 31
            rn = (w >> 5) & 31
            rm = (w >> 16) & 31
            top = w >> 24
            # --- nhảy ---
            if (w & 0xFC000000) == 0x14000000:
                npc = pc + sx(w & 0x3FFFFFF, 26) * 4
            elif (w & 0xFF000010) == 0x54000000:
                if cond(w & 15): npc = pc + sx((w >> 5) & 0x7FFFF, 19) * 4
            elif (w & 0xFFFFFC1F) == 0xD61F0000:
                npc = reg(rn)
            elif (w & 0xFFFFFC1F) == 0xD63F0000:
                t = reg(rn)
                if t != HOST: raise RuntimeError('blr tới địa chỉ lạ %x' % t)
                x[0] = host(x[0], x[1], x[2], x[3]) & M64
                for r in (16, 17): pass
            # --- adr / adrp ---
            elif (w & 0x9F000000) == 0x10000000:
                imm = sx(((w >> 5) & 0x7FFFF) << 2 | ((w >> 29) & 3), 21)
                setreg(rd, pc + imm)
            elif (w & 0x9F000000) == 0x90000000:
                imm = sx(((w >> 5) & 0x7FFFF) << 2 | ((w >> 29) & 3), 21)
                setreg(rd, ((pc >> 12) + imm) << 12)
            # --- mov wide ---
            elif (w & 0xFF800000) == 0xD2800000:
                setreg(rd, ((w >> 5) & 0xFFFF) << (16 * ((w >> 21) & 3)))
            elif (w & 0xFF800000) == 0x92800000:
                setreg(rd, ~(((w >> 5) & 0xFFFF) << (16 * ((w >> 21) & 3))))
            elif (w & 0xFF800000) == 0xF2800000:
                sh = 16 * ((w >> 21) & 3)
                setreg(rd, (reg(rd) & ~(0xFFFF << sh)) | (((w >> 5) & 0xFFFF) << sh))
            # --- logic reg (shift 0) ---
            elif (w & 0xFF000000) in (0x8A000000, 0xAA000000, 0xCA000000, 0xEA000000):
                a = reg(rn); b = reg(rm)
                if (w >> 21) & 1: b = ~b & M64
                t = w & 0xFF000000
                r = a & b if t in (0x8A000000, 0xEA000000) else (a | b if t == 0xAA000000 else a ^ b)
                if t == 0xEA000000:
                    N = r >> 63; Z = 1 if r == 0 else 0; C = V = 0
                setreg(rd, r)
            elif (w & 0xFFE0FFE0) == 0x2A0003E0:  # mov w, w
                setreg(rd, reg(rm) & 0xFFFFFFFF)
            # --- add/sub ---
            elif (w & 0xFF200000) in (0x8B000000, 0xCB000000, 0xEB000000):
                t = w & 0xFF000000
                r = addsub(reg(rn), reg(rm), t != 0x8B000000, t == 0xEB000000)
                setreg(rd, r)
            elif (w & 0xFF000000) in (0x91000000, 0xD1000000, 0xF1000000):
                t = w & 0xFF000000
                imm = (w >> 10) & 0xFFF
                if (w >> 22) & 1: imm <<= 12
                r = addsub(reg(rn), imm, t != 0x91000000, t == 0xF1000000)
                setreg(rd, r)
            # --- mul/div/shift ---
            elif (w & 0xFFE0FC00) == 0x9B007C00:
                setreg(rd, reg(rn) * reg(rm))
            elif (w & 0xFFE08000) == 0x9B008000:
                ra = (w >> 10) & 31
                setreg(rd, reg(ra) - reg(rn) * reg(rm))
            elif (w & 0xFFE0FC00) == 0x9AC00C00:
                a = sx(reg(rn), 64); b = sx(reg(rm), 64)
                q = 0 if b == 0 else int(abs(a) // abs(b)) * (1 if (a < 0) == (b < 0) else -1)
                setreg(rd, q)
            elif (w & 0xFFE0FC00) == 0x9AC02000:
                setreg(rd, reg(rn) << (reg(rm) & 63))
            elif (w & 0xFFE0FC00) == 0x9AC02400:
                setreg(rd, reg(rn) >> (reg(rm) & 63))
            elif (w & 0xFFE0FC00) == 0x9AC02800:
                setreg(rd, sx(reg(rn), 64) >> (reg(rm) & 63))
            elif (w & 0xFFE00C00) == 0x9A800400:  # csinc
                c = (w >> 12) & 15
                setreg(rd, reg(rn) if cond(c) else reg(rm) + 1)
            # --- bộ nhớ (số nguyên & D) ---
            elif (w & 0x3B000000) == 0x39000000 or (w & 0x3B200000) == 0x38000000:
                fp = (w >> 26) & 1 == 1
                size = 1 << (w >> 30)
                ld = (w >> 22) & 1
                if (w >> 24) & 1:  # unsigned imm
                    addr = reg(rn) + ((w >> 10) & 0xFFF) * size
                else:
                    imm9 = sx((w >> 12) & 0x1FF, 9)
                    mode = (w >> 10) & 3
                    if mode == 0: addr = reg(rn) + imm9      # unscaled
                    elif mode == 1: addr = reg(rn)            # post
                    elif mode == 3: addr = reg(rn) + imm9     # pre
                    else: raise RuntimeError('chế độ bộ nhớ lạ %08x' % w)
                    if mode in (1, 3): x[rn] = (reg(rn) + imm9) & M64
                addr &= M64
                if fp:
                    if ld: d[rd] = struct.unpack('<d', mem.rd(addr, 8))[0]
                    else: mem.wr(addr, struct.pack('<d', d[rd]))
                elif ld:
                    v = {8: mem.r64, 4: mem.r32, 1: mem.r8}[size](addr)
                    setreg(rd, v)
                else:
                    {8: mem.w64, 4: mem.w32, 1: mem.w8}[size](addr, reg(rd))
            # --- FP ---
            elif (w & 0xFFE0FC00) == 0x1E602800: d[rd] = d[rn] + d[rm]
            elif (w & 0xFFE0FC00) == 0x1E603800: d[rd] = d[rn] - d[rm]
            elif (w & 0xFFE0FC00) == 0x1E600800: d[rd] = d[rn] * d[rm]
            elif (w & 0xFFE0FC00) == 0x1E601800:
                d[rd] = d[rn] / d[rm] if d[rm] != 0 else (math.copysign(math.inf, d[rn]) if d[rn] != 0 else math.nan)
            elif (w & 0xFFE0FC1F) == 0x1E602000:
                a, b = d[rn], d[rm]
                if math.isnan(a) or math.isnan(b): N, Z, C, V = 0, 0, 1, 1
                elif a == b: N, Z, C, V = 0, 1, 1, 0
                elif a < b: N, Z, C, V = 1, 0, 0, 0
                else: N, Z, C, V = 0, 0, 1, 0
            elif (w & 0xFFFFFC00) == 0x9E620000: d[rd] = float(sx(reg(rn), 64))
            elif (w & 0xFFFFFC00) == 0x9E780000:
                v = d[rn]
                if math.isnan(v): r = 0
                elif v >= 2.0 ** 63: r = (1 << 63) - 1
                elif v <= -(2.0 ** 63): r = -(1 << 63)
                else: r = int(v)
                setreg(rd, r)
            elif (w & 0xFFFFFC00) == 0x1E644000: d[rd] = float(round(d[rn])) if math.isfinite(d[rn]) else d[rn]
            elif (w & 0xFFFFFC00) == 0x1E654000: d[rd] = float(math.floor(d[rn])) if math.isfinite(d[rn]) else d[rn]
            elif (w & 0xFFFFFC00) == 0x1E64C000: d[rd] = float(math.ceil(d[rn])) if math.isfinite(d[rn]) else d[rn]
            elif (w & 0xFFFFFC00) == 0x1E65C000: d[rd] = float(math.trunc(d[rn])) if math.isfinite(d[rn]) else d[rn]
            elif w == 0xD53BE040: x[0] = steps  # mrs x0, cntvct_el0
            else:
                raise RuntimeError('lệnh chưa hỗ trợ %08x tại %x' % (w, pc))
            pc = npc
    except SystemExit as e:
        return bytes(out), e.code, steps


if __name__ == '__main__':
    img = open(sys.argv[1], 'rb').read()
    stdin = open(sys.argv[2], 'rb').read() if len(sys.argv) > 2 else b''
    o, code, steps = run(img, stdin)
    sys.stdout.buffer.write(o)
    sys.stderr.write('[mô phỏng: %d bước, mã thoát %s]\n' % (steps, code))
    sys.exit(code)
