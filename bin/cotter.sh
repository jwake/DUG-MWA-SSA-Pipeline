#! /bin/bash -l
#rj name=cotter nodes=1 features=knl,fastio runtime=1.5

module add gcc/9.2.0
module add openmpi/4.0.3-mlnx
source /p8/mcc_icrar/sw/env.sh

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


datadir=${base}processing/${obsnum}

cd ${datadir}

cotter -norfi -initflag 2 -timeres 2 -freqres 40 *gpubox* -absmem 60 -edgewidth 118 -m ${obsnum}.metafits -o ${obsnum}.ms

applysolutions ${obsnum}.ms ${calibrationSolution}

end=`date +%s`
runtime=$((end-start))
echo "the job run time ${runtime}"

}
