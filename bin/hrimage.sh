#! /bin/bash -l
#rj name=hrimage nodes=1 features=centos7,knl,fastio,localdisk runtime=1

TEMP=${TMPDIR}

set -x
{


mem=20
module add gcc/9.2.0
module add openmpi/4.0.3-mlnx
source /p8/mcc_icrar/sw/env.sh

datadir=${base}processing/${obsnum}
cd ${datadir}

b=${ts}

for g in `seq 1 ${pernode}`;
do
{
    i=$((b+g*1))
    j=$((i+1))
    skip=$(((g-1)*${pernode}))
    if [[ $i -gt ${maxTimeStep} ]]; then 
        exit
    fi
    rm -rf ${TEMP}/${i}
    mkdir -p ${TEMP}/${i}/tmp
    cd ${TEMP}/${i}
    WSCLEAN_OPTS="-j 8 -name ${obsnum}-2m-${i} -size 1400 1400 -temp-dir ${TEMP}/${i}/tmp -abs-mem ${mem} -interval ${i} ${j} -channels-out ${channels} -weight natural -scale 5amin -parallel-gridding 32 -parallel-reordering 32 ${datadir}/${obsnum}.ms"
    echo "Running wsclean ${WSCLEAN_OPTS}"
    KMP_HW_SUBSET=8c@${skip},4t OMP_WAIT_POLICY=passive KMP_NESTED=true OMP_NESTED=true KMP_AFFINITY=balanced wsclean ${WSCLEAN_OPTS}

    rm ${obsnum}-2m-${i}*image.fits
    mv ${obsnum}-2m-${i}*dirty.fits ${datadir}
    
    rm ${obsnum}-2m-${i}*tmp.fits
    rm -r ${TEMP}/${i}
}&
done

for job in `jobs -p`
do
echo $job
    wait $job || let "FAIL+=1"
done

# Note: cleanup is now done elsewhere since there will be other processes using the input/output folder

}


