source /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.4-env.sh
cd $RT/bareMetalC
awk '/nvfp4_e2e/ {print "\tnvfp4_e2e \\"; print "\tnvfp4_e2e_s2 \\"; print "\tnvfp4_e2e_s3 "; next} {print}' Makefile > /tmp/Makefile.new && cp /tmp/Makefile.new Makefile
git diff Makefile | grep '^[+-]'
