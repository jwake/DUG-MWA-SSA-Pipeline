#! /bin/bash -l
#BATCH --export=NONE
#SBATCH -M zeus
#SBATCH -p workq
#SBATCH --time=8:00:00
#SBATCH --ntasks=28
#SBATCH --mem=122GB
#SBATCH -J cotter
#SBATCH --mail-type FAIL,TIME_LIMIT,TIME_LIMIT_90
#SBATCH --mail-user sirmcmissile47@gmail.com

start=`date +%s`

source /group/mwa/software/module-reset.sh
module use /group/mwa/software/modulefiles
module load MWA_Tools/mwa-sci
module list

set -x 

{
obsnum=OBSNUM
base=BASE
calibrationSolution=

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
