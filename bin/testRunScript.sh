#! /bin/bash -l
#SBATCH --export=NONE
#SBATCH -M zeus
#SBATCH -p workq
#SBATCH --time=24:00:00
#SBATCH --ntasks=28
#SBATCH --mem=120GB
#SBATCH -J testPipeline
#SBATCH --mail-type FAIL,TIME_LIMIT,TIME_LIMIT_90
#SBATCH --mail-user sirmcmissile47@gmail.com

module load MWA_Tools/mwa-sci

set -x

obsnum=1165782616
basedir=/group/mwasci/sprabu/satellites/DUG-MWA-SSA-Pipeline
targetdir=${basedir}/processing/${obsnum}

cd ${targetdir}

#### make measurment set ####
cotter -norfi -initflag 2 -timeres 2 -freqres 40 *gpubox* -absmem 110 -edgewidth 80 -m ${obsnum}.metafits -o ${obsnum}.ms
rm *gpubox*.fits

#### apply calibration solution ####
applysolutions ${obsnum}.ms HexFMSurveySolutionHydA.bin

#### make high time and freq images ####
for g in in `seq 0 56`;
do
	i=$((g*1))
	j=$((i+1))
	wsclean -name ${obsnum}-2m-${i} -size 700 700 \
		-abs-mem 120 -interval ${i} ${j} -channels-out 96\
		-weight natural -scale 10amin ${obsnum}.ms
	rm *image.fits
done


#### run RFISeeker ####
for q in $(seq 56)
do
  while [[ $(jobs | wc -l) -ge 28 ]]
  do
    wait -n $(jobs -p)
  done
  RFISeeker --obs ${obsnum} --freqChannels 96 --seedSigma 6 --floodfillSigma 3 --timeStep ${q} --prefix 6Sigma3floodfill --DSNRS False &
done

t=0
for job in `jobs -p`
do
        pids[${t}]=${job}
        t=$((t+1))
done
for pid in ${pids[*]}; do
        wait ${pid}
done


#### cleaning up data #### 
for ((l=0;l<57;l++))
do
	rm *${l}-dirty.fits
done
rm -r ${obsnum}.ms

###################### end ###########################


