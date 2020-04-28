#! /bin/bash -l
#SBATCH --export=NONE
#SBATCH -M zeus  
#SBATCH -p workq 
#SBATCH --time=16:00:00
#SBATCH --ntasks=28
#SBATCH --mem=120GB
#SBATCH -J RFISeeker
#SBATCH --mail-type FAIL,TIME_LIMIT,TIME_LIMIT_90
#SBATCH --mail-user sirmcmissile47@gmail.com

set -x
{

obsnum=OBSNUM
base=BASE
timeSteps=
channels=

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

datadir=${base}processing/${obsnum}
cd ${datadir}

# the below scipt parrallel spaws 28 python scipts on the requested 28 cores. 
for q in $(seq ${timeSteps})
do
  while [[ $(jobs | wc -l) -ge 28 ]]
  do
    wait -n $(jobs -p)
  done
  RFISeeker --obs ${obsnum} --freqChannels ${channels} --seedSigma 6 --floodfillSigma 3 --timeStep ${q} --prefix 6Sigma3Floodfill --DSNRS=False &

done

i=0
for job in `jobs -p`
do
        pids[${i}]=${job}
        i=$((i+1))
done
for pid in ${pids[*]}; do
        wait ${pid}
done

}
