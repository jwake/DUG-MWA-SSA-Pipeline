#! /bin/bash -l
#rj name=cotter nodes=1 features=knl,fastio runtime=1.5


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

module add openmpi/4.0.3-mlnx
module add gcc/9.2.0
source /p8/mcc_icrar/sw/env.sh

datadir=${base}/processing/${obsnum}

cd ${datadir}

cotter -j 256 -norfi -initflag 2 -timeres 2 -freqres 40 *gpubox* -absmem 60 -edgewidth 118 -m ${obsnum}.metafits -o ${obsnum}.ms

applysolutions ${obsnum}.ms ${calibrationSolution}

end=`date +%s`
runtime=$((end-start))
echo "the job run time ${runtime}"

}
