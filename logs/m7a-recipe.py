# Reverse-engineer the MX branch's operand quantization recipe from its committed test headers.
import re, sys, numpy as np
sys.path.insert(0, 'refmodel')
d = 'logs/m7a-data/'
def arr(txt, name):
    m = re.search(r'static const \w+ %s\[[^=]*=\s*\{(.*?)\n\};' % name, txt, re.S)
    return np.array([int(x, 16) for x in re.findall(r'0x[0-9a-fA-F]+', m.group(1))])
def e4m3(c):
    s = -1 if c & 128 else 1; e = (c >> 3) & 15; m = c & 7
    return s * ((m/8) * 2.0**-6 if e == 0 else (1+m/8) * 2.0**(e-7))
def e2m1(c):
    s = -1 if c & 8 else 1; e = (c >> 1) & 3; m = c & 1
    return s * (m/2 if e == 0 else (1+m/2) * 2.0**(e-1))
for f in ('matmul_fp8_64x64.h', 'matmul_fp8_128x128.h'):
    t = open(d+f).read()
    M = int(re.search(r'#define MATMUL_M\s+(\d+)', t).group(1)); K = int(re.search(r'#define MATMUL_K\s+(\d+)', t).group(1))
    A = np.array([e4m3(c) for c in arr(t, 'A_in')]).reshape(M, K)
    sc = arr(t, 'A_scales_row').reshape(K//32, M)
    blk = np.abs(A).reshape(M, K//32, 32).max(-1)
    print(f, 'E4M3 A: per-32-block max |P| over blocks: min %.3f median %.3f max %.3f; fraction in [1,2]: %.3f, in [256,448]: %.3f' % (blk.min(), np.median(blk), blk.max(), np.mean((blk>=1)&(blk<=2)), np.mean(blk>=256)))
    print('   scale codes (e8m0) range', sc.min(), sc.max(), '-> exponents', sc.min()-127, sc.max()-127)
for f in ('matmul_fp4_64x64.h', 'matmul_fp4_128x128.h'):
    t = open(d+f).read()
    M = int(re.search(r'#define MATMUL_M\s+(\d+)', t).group(1)); K = int(re.search(r'#define MATMUL_K\s+(\d+)', t).group(1))
    hw = arr(t, 'A_in_hw').reshape(M//2, K)
    lo, hi = hw & 15, hw >> 4
    A = np.zeros((M, K)); A[0::2] = [[e2m1(c) for c in r] for r in lo]; A[1::2] = [[e2m1(c) for c in r] for r in hi]
    blk = np.abs(A).reshape(M, K//32, 32).max(-1)
    vals, cnt = np.unique(blk, return_counts=True)
    print(f, 'E2M1 A: block max |P| histogram', dict(zip(vals.tolist(), cnt.tolist())))
    sc = arr(t, 'A_scales_row'); print('   scale exps', sc.min()-127, sc.max()-127)
