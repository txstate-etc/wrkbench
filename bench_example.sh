#!/bin/bash
# Example usage with graphql.lua script:
#   ./bench_example.sh 1,2,2,3 queries.example.json http://localhost:8080/graphql
# Usage parameters for wrk2:
#   wrk2 -c10 -d20 -t2 -R10 -L -s /scripts/script.lua https://svc.dept.qual.txstate.edu/graphql -- <parameters for script.lua go here>
#   -c: connections num. The Number of connections that will be kept open.
#   -d: duration, test time. Note that it has a 10 second calibration time, so this should be specified no shorter than 20s.
#   -t: threads num. Just set it to cpu cores.
#   --timeout num, how long to allow a connection to wait before reset (ECONNRESET)
#   -R: or --rate, expected throughput, the result RPS which is real throughput, will be lower than this value.
#   -L: report latency statistics once benchmark testing is done.
#   -s: script to run. Arguments that come after "--" will be passed to the script.

if ! [ -z "$REGISTRY" ] && ! [[ "$REGISTRY" == */ ]]; then REGISTRY=$REGISTRY/; fi
INDEX=${1:-1}
DATA=${2:-queries.example.json}
URL=${3:-http://localhost:8080/graphql}
SCRIPT=graphql.lua
SLOWEST=${4}
if [ "$SLOWEST" == 'slowest' ]; then
  docker run --rm \
    -v `pwd`/scripts:/scripts \
    -v `pwd`/data:/data \
    ${REGISTRY}wrkbench:qual wrk2 -R1 -t1 --timeout 30s -c2 -d1m -L -s /scripts/$SCRIPT $URL -- -i$INDEX -d/data/$DATA
else  
  docker run --rm \
   -v `pwd`/scripts:/scripts \
   -v `pwd`/data:/data \
   ${REGISTRY}wrkbench:qual wrk2 -R4 -t2 --timeout 5s -c8 -d1m -L -s /scripts/$SCRIPT $URL -- -i$INDEX -d/data/$DATA
fi
