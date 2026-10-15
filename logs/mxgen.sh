cd ~ && [ -d MxGen ] || git clone -q https://github.com/ucb-bar/MxGen.git
cd ~/MxGen && git log -1 --format="head: %h %ad %s" --date=short
echo "--- LICENSE history"; git log --format="%h %ad %an: %s" --date=short --follow -- LICENSE* 
echo "--- LICENSE head"; head -5 LICENSE*
echo "--- earlier license text (first commit of LICENSE)"; f=$(git log --format=%h --diff-filter=A -- LICENSE* | tail -1); [ -n "$f" ] && git show $f --stat --format="%h %ad" --date=short | head -5
git log --format="%h" -- LICENSE* | sed -n 2p | xargs -r -I{} git show {}:LICENSE 2>/dev/null | head -5
echo "--- other license mentions"; grep -ril "license" --include=*.md --include=*.scala --include=*.sbt . | grep -v "^./LICENSE" | head
ls
