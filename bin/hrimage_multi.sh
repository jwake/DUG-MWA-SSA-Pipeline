#! /bin/bash -l
#rj name=hrimage nodes=1 features=centos7,knl,fastio runtime=17.5

TEMP=${TMPDIR}
#TEMP=`mktemp -d -p /p9/mcc_icrar/MWA-SSA/scratch`

set -x

module add gcc/9.2.0
module add openmpi/4.0.5-mlnx-icc
source /p9/mcc_icrar/sw/env.sh

datadir=${base}/processing/${obsnum}
set -e

cd ${TEMP}

ts2=$((${ts}+1))

jparam=${wsclean_cpus}
grid=$((${wsclean_cpus} / 2))
reorder=$((${wsclean_cpus} / 2))
WSCLEAN_OPTS="-j ${jparam} -no-clean -no-model -no-residual -name ${obsnum}-2m-${ts} -size 1400 1400 -temp-dir ${TEMP} -abs-mem ${wsclean_ram} -interval ${ts} ${ts2} -channels-out ${channels} -weight natural -scale 5amin -parallel-gridding ${grid} -parallel-reordering ${reorder} ${datadir}/${obsnum}.ms"
affinity=`/d/sw/slurm/latest/bin/scontrol show --details job=${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID} -o |sed -E 's/(.*?)CPU_IDs=([^ ]*) (.*?)/\2/'|sed -E 's/([0123456789-]+)[,]?/pu:\1 /g'|head -n 1`
OMP_WAIT_POLICY=passive OMP_MAX_ACTIVE_LEVELS=3 KMP_AFFINITY=compact,granularity=core /d/sw/hwloc/2.0.4/bin/hwloc-bind -l ${affinity} wsclean ${WSCLEAN_OPTS}

mv ${obsnum}-2m-${i}*dirty.fits ${datadir}
    
rm -f ${obsnum}-2m-${i}*image.fits
rm -f ${obsnum}-2m-${i}*tmp.fits
rm -rf ${TEMP}/${i}

