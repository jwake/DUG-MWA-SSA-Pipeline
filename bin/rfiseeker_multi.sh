#! /bin/bash 
#rj name=RFISeeker nodes=1 features=centos7,knl,fastio runtime=0.25 mem=1G cpus=4

start=`date +%s`
set -x
{

module add gcc/9.2.0
module add openmpi/4.0.5-mlnx-icc
source /p9/mcc_icrar/sw/env.sh

while getopts 's:f:' OPTION
do
    case "$OPTION" in
        s)
            timeSteps=${OPTARG}
            ;;
        f)
            channels=${OPTARG}
            ;;
    esac
done

module add gcc/9.2.0
module add openmpi/4.0.3-mlnx
source /p9/mcc_icrar/sw/env.sh
set -e

datadir=${base}/processing/${obsnum}
cd ${datadir}

echo "RFISeeker --obs ${obsnum} --freqChannels ${channels} --seedSigma 6 --floodfillSigma 3 --timeStep ${ts} --prefix 6Sigma3Floodfill --DSNRS=False"
affinity=`/d/sw/slurm/latest/bin/scontrol show --details job=${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID} -o |sed -E 's/(.*?)CPU_IDs=([^ ]*) (.*?)/\2/'|sed -E 's/([0123456789-]+)[,]?/pu:\1 /g'|head -n 1`
OMP_WAIT_POLICY=passive OMP_MAX_ACTIVE_LEVELS=3 KMP_AFFINITY=compact,granularity=core /d/sw/hwloc/2.0.4/bin/hwloc-bind -l ${affinity} RFISeeker --obs ${obsnum} --freqChannels ${channels} --seedSigma 6 --floodfillSigma 3 --timeStep ${ts} --prefix 6Sigma3Floodfill --DSNRS=False --imgSize 1400

}
