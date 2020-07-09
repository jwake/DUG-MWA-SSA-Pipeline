#! /bin/bash -l
#BATCH --export=NONE
#SBATCH -M zeus
#SBATCH -p workq
#SBATCH --time=8:00:00
#SBATCH --ntasks=28
#SBATCH --mem=122GB
#SBATCH -J calibrate
#SBATCH --mail-type FAIL,TIME_LIMIT,TIME_LIMIT_90
#SBATCH --mail-user sirmcmissile47@gmail.com

start=`date +%s`

source /group/mwa/software/module-reset.sh
module use /group/mwa/software/modulefiles
module load MWA_Tools/mwa-sci
module list
module load python/3.6.3

set -x 

{
obsnum=OBSNUM
base=BASE
calibrationModel=

while getopts 'm:' OPTION
do
    case "$OPTION" in
        c)
            calibrationModel=${OPTARG}
            ;;
    esac
done


datadir=${base}processing/${obsnum}

cd ${datadir}

## copy over the mwapy module
cp -r /astro/mwasci/sprabu/satellites/mwapy .

# flag baselines in DATA column
aoflagger ${obsnum}.ms

# flag tile in DATA column
python tileFlagger.py --obs ${obsnum} --data_col DATA

# flag channels in DATA column
python freqFlag.py --obs ${obsnum} --col DATA

# round 1 calibration using source model
calibrate -absmem 120 -m ../model-${calibrationModel}*withalpha.txt -minuv 150 ${obsnum}.ms round1_sol.bin

# apply round 1 solution to measurement set
applysolutions ${obsnum}.ms round1_sol.bin

# flag baselines in CORRECTED_DATA col
aoflagger ${obsnum}.ms

# flag channels in CORRECTED_DATA col
python freqFlag.py --obs ${obsnum} --col CORRECTED_DATA

# calibrate with the new flags and model
calibrate -absmem 120 -m ../model-${calibrationModel}*withalpha.txt -minuv 150 ${obsnum}.ms round2_sol.bin

## interpolate calibration solution for flagged freq
python solInterpolate.py --inputFile round2_sol.bin --obs ${obsnum}

## applysolution
applysolutions ${obsnum}.ms ${obsnum}.bin

end=`date +%s`
runtime=$((end-start))
echo "the job run time ${runtime}"

}
