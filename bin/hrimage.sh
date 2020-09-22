#! /bin/bash -l
#rj name=hrimage nodes=1 features=centos7,knl,fastio runtime=1

TEMP=${TMPDIR}
FAIL=0
start=`date +%s`

set -x
{


mem=20
module add gcc/9.2.0
module add openmpi/4.0.5-mlnx-icc
source /p8/mcc_icrar/sw/env.sh

datadir=${base}/processing/${obsnum}
set -e
cd ${datadir}

b=${ts}

for g in `seq 1 ${pernode}`;
do
{
    j=$((b+g*1))
    i=$((j-1))
    skip=$(((g-1)*${pernode}))
    if [[ $i -gt $((1+${maxTimeStep})) ]]; then 
        exit
    fi
    rm -rf ${TEMP}/${i}
    mkdir -p ${TEMP}/${i}/tmp
    cd ${TEMP}/${i}
    WSCLEAN_OPTS="-j 8 -no-clean -no-model -no-residual -name ${obsnum}-2m-${i} -size 1400 1400 -temp-dir ${TEMP}/${i}/tmp -abs-mem ${mem} -interval ${i} ${j} -channels-out ${channels} -weight natural -scale 5amin -parallel-gridding 32 -parallel-reordering 32 ${datadir}/${obsnum}.ms"
    echo "Running wsclean ${WSCLEAN_OPTS}"
    set -e
    OMPI_PREFIX_ENV=/p8/mcc_icrar/000scratch KMP_HW_SUBSET="8c@${skip}" OMP_WAIT_POLICY=passive OMP_MAX_ACTIVE_LEVELS=3 KMP_AFFINITY=compact,granularity=core wsclean ${WSCLEAN_OPTS}
    
    mv ${obsnum}-2m-${i}*dirty.fits ${datadir}
    
    rm -f ${obsnum}-2m-${i}*image.fits
    
    rm -f ${obsnum}-2m-${i}*tmp.fits
    rm -rf ${TEMP}/${i}
}&
done

for job in `jobs -p`
do
echo $job
    wait $job || let "FAIL+=1"
done

# Note: cleanup is now done elsewhere since there will be other processes using the input/output folder

end=`date +%s`
runtime=$((end-start))
echo "the job run time ${runtime}"


}
exit $FAIL


