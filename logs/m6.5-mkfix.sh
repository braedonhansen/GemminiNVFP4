cd ~/chipyard-mx/generators/gemmini/software/gemmini-rocc-tests/bareMetalC
L=$(grep -n 'nvfp4_e2e_s3 .n' Makefile | cut -d: -f1); echo line=$L
[ -n "$L" ] || exit 1
sed -i "${L}d" Makefile
sed -i "$((L-1))r /dev/stdin" Makefile <<'EOT'
	nvfp4_e2e_s3 \
	nvfp4_mt_m64n64k128 \
	nvfp4_mt_m32n96k64 \
	nvfp4_mt_m96n32k256 \
	nvfp4_mt_m64n64k512 
EOT
git diff Makefile | grep '^[+-]' | cat -A | cut -c1-80
