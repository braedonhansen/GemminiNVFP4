R=https://raw.githubusercontent.com/ucb-bar/MxGen/18bdadacc67aeb755d379c177882b1e4cda13d9b/src/main/scala/mxgen
curl -s $R/MxFPMul.scala | grep -n -i -E "class MxFpMul|rec_c|cType|accFormat|productFormat|PROD_FLOOR|flush|io\.out|useMxPEAddRecFN|latency" | head -40
curl -s $R/MxParameters.scala | grep -n -i -E "case class MxConfig|accFormat|productFormat|object MxFormat|FP4|E2M1|BF16|FP32" | head -30
