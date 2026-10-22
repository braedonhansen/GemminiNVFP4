#!/bin/bash
# usage: m7p-ssh-cmd.sh <job>   -- PRINTS (never runs) the two single-connection commands for the coordinator's terminal tab.
JOB=$1; [ -n "$JOB" ] || { echo "usage: $0 <job>" >&2; exit 2; }
HOST=${M7P_HOST:?set M7P_HOST=user@server}
T=$HOME/nvfp4-logs/m7p/jobs
# the remote login shell is tcsh: use `>&` (not `2>&1`), detach stdin, and background only the inner subshell
# (a trailing & after `a && b && c` would background the whole list, including the `tar xz` that reads the tarball from stdin)
echo "ssh $HOST \"mkdir -p ~/m7p/$JOB && cd ~/m7p/$JOB && tar xz && (nohup tcsh run.csh >& run.log < /dev/null &)\" < $T/$JOB.tar.gz"
echo "ssh $HOST \"cd ~/m7p/$JOB && tar cz reports run.log\" > $T/$JOB.out.tgz"
