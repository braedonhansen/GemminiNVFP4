cd ~/chipyard/generators/gemmini
B=origin/gemmini-mx-cleanup
echo ---mxgen submodule files; git -C mxgen ls-tree -r --name-only 18bdadacc67aeb755d379c177882b1e4cda13d9b 2>&1 | head -50
ls mxgen 2>&1 | head
echo ---grep block
git grep -n -i -E "blockSize|block_size|BLOCK_SIZE|mxBlock|MX_BLOCK|blockK|scaleBlock" $B -- 'src/main/scala' | head -60
