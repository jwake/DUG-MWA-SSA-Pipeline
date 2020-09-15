#! /bin/bash 
#rj name=RFISeeker nodes=1 features=centos7,knl,fastio runtime=1

start=`date +%s`

set -x
{

mem=20
module add gcc/9.2.0
module add openmpi/4.0.x-mlnx-icc
source /p8/mcc_icrar/sw/env.sh

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
source /p8/mcc_icrar/sw/env.sh


datadir=${base}/processing/${obsnum}
cd ${datadir}

# the below scipt parrallel spaws 28 python scipts on the requested 28 cores. 
for q in $(seq 1 ${pernode})
do
{
  set -e
  b=$((ts + q))
  if [[ $b -gt ${maxTimeStep} ]]; then
    exit
  fi
  echo "RFISeeker --obs ${obsnum} --freqChannels ${channels} --seedSigma 6 --floodfillSigma 3 --timeStep ${b} --prefix 6Sigma3Floodfill --DSNRS=False"
  RFISeeker --obs ${obsnum} --freqChannels ${channels} --seedSigma 6 --floodfillSigma 3 --timeStep ${b} --prefix 6Sigma3Floodfill --DSNRS=False
}&
done

i=0
for job in `jobs -p`
do
  wait ${job}
done

### combine data and make it into a vo table
combinedMeasurements.py --t1 1 --t2 55 --obs ${obsnum} --prefix 6Sigma3Floodfill --hpc dug

if [[ "${skip_result_copy}" != "1" ]]; then
  ## copy the data over to storage
  scp ${obsnum}-dug-measurements.fits zeus:'/group/mwasci/sprabu/rfiseekerLog'
fi

end=`date +%s`
runtime=$((end-start))
echo "the job run time ${runtime}"


}
