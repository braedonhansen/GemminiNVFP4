# Re-extracts the job tarball into a scratch dir and verifies the MANIFEST hashes + counts what was checked
J=$1
D=$(mktemp -d ~/nvfp4-logs/m7p/jobs/chk.XXXX); tar xzf ~/nvfp4-logs/m7p/jobs/$J.tar.gz -C $D; cd $D
N=$(wc -l < MANIFEST); OK=$(sha256sum -c MANIFEST 2>&1 | grep -c ": OK"); BAD=$(sha256sum -c MANIFEST 2>&1 | grep -vc ": OK")
echo "manifest entries=$N ok=$OK bad=$BAD"; [ "$N" -gt 100 ] && [ "$OK" = "$N" ] && [ "$BAD" = 0 ] && echo PACKCHECK-PASS || echo PACKCHECK-FAIL
zcat act/kernel.vcd.gz | head -c 40 | head -1; cd ~; rm -rf $D
