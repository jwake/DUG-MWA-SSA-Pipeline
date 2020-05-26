#! /bin/bash -l
#SBATCH --export=NONE
#SBATCH -M zeus
#SBATCH -p workq
#SBATCH --time=12:00:00
#SBATCH --ntasks=28
#SBATCH --mem=122GB
#SBATCH -J arg_hrimage
#SBATCH --mail-type FAIL,TIME_LIMIT,TIME_LIMIT_90
#SBATCH --mail-user sirmcmissile47@gmail.com

source /group/mwa/software/module-reset.sh
module use /group/mwa/software/modulefiles
module load MWA_Tools/mwa-sci
module list

set -x
{

obsnum=OBSNUM
base=BASE
datadir=${base}processing/${obsnum}
timeStep=TIMESTEP
channels=CHANNELS


cd ${datadir}

mem=115

mkdir ${timeStep}

t1=$((timeStep*1))
t2=$((t1+1))

wsclean -name ${obsnum}-2m-${timeStep} -size 5000 5000 -temp-dir ${timeStep} \
        -abs-mem ${mem} -interval ${t1} ${t2} -channels-out ${channels}\
        -weight natural -scale 1.25amin  ${obsnum}.ms

rm -r ${timeStep}

rm *image.fits


}

