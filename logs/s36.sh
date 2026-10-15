curl -s "https://api.github.com/repos/ucb-bar/libgemmini/commits/3de3cbc5" | python3 -c "
import sys,json
d=json.load(sys.stdin)
print(d['commit']['message'])
for p in d['parents']: print(p['sha'][:8])
"
curl -s "https://api.github.com/repos/ucb-bar/libgemmini/compare/ea8f7ed7afd68e001fb06ddccad9a023c990961d~1...ea8f7ed7afd68e001fb06ddccad9a023c990961d" | python3 -c "
import sys,json
d=json.load(sys.stdin)
for f in d.get('files',[]): print('##',f['filename']); print(f.get('patch','')[:1500])
"
# does the mx pin still have the spike-bump-affected lines?
L=876631072ecc7cc8197df5dc69c4d26bd4cd5f54
curl -s https://raw.githubusercontent.com/ucb-bar/libgemmini/$L/gemmini.h | grep -n -E "reg_t|processor_t|require_extension|extension_t|insn_t|CUSTOM" | head -10
