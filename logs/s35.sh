L=876631072ecc7cc8197df5dc69c4d26bd4cd5f54
curl -s "https://api.github.com/repos/ucb-bar/libgemmini/compare/$L...master" | python3 -c "
import sys,json
d=json.load(sys.stdin)
print(d['status'],d['ahead_by'],d['behind_by'])
for c in d['commits']: print(c['sha'][:8],c['commit']['committer']['date'][:10],c['commit']['message'].split('\n')[0])
for f in d['files'][:15]: print(f['filename'],f['changes'])
"
