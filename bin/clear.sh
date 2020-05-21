#! /bin/bash -l
#SBATCH --export=NONE
#SBATCH -M zeus
#SBATCH -p workq
#SBATCH --time=1:00:00
#SBATCH --ntasks=4
#SBATCH --mem=10GB
#SBATCH -J clear
#SBATCH --mail-type FAIL,TIME_LIMIT,TIME_LIMIT_90
#SBATCH --mail-user sirmcmissile47@gmail.com

start=`date +%s`


set -x

{

obsnum=OBSNUM
base=BASE
datadir=${base}processing/${obsnum}
cd ${datadir}

for ((i=0;i<10;i++));
do
    rm *${i}-dirty.fits
done

end=`date +%s`
runtime=$((end-start))
echo "the job run time ${runtime}"

}
