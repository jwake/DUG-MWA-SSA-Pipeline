#! /bin/bash -l
#rj name=cotter nodes=1 features=knl,fastio runtime=4.25


start=`date +%s`

set -x 

{


while getopts 'c:' OPTION
do
    case "$OPTION" in
        c)
            calibrationSolution=${OPTARG}
            ;;
    esac
done

module add openmpi/4.0.5-mlnx
module add gcc/9.2.0
source /p9/mcc_icrar/sw/env.sh

datadir=${base}/processing/${obsnum}

cd ${datadir}
set -e

OMP_WAIT_POLICY=passive OMP_MAX_ACTIVE_LEVELS=3 KMP_HW_SUBSET="64c@0" /d/sw/hwloc/2.0.4/bin/hwloc-bind -l pu:1-256 cotter -j 64 -norfi -initflag 2 -timeres 2 -freqres 40 *gpubox* -absmem 100 -edgewidth 80 -m ${obsnum}.metafits -o ${obsnum}.ms

applysolutions ${obsnum}.ms ${calibrationSolution}

end=`date +%s`
runtime=$((end-start))
echo "the job run time ${runtime}"
touch .cotter_complete
}
