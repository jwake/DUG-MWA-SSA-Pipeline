#!/bin/bash
#rj name=combine_copy_results nodes=1 runtime=1

module add gcc/9.2.0
source /p8/mcc_icrar/sw/env.sh

datadir=${base}/processing/${obsnum}
set -e
cd ${datadir}

### combine data and make it into a vo table
combinedMeasurements.py --t1 1 --t2 55 --obs ${obsnum} --prefix 6Sigma3Floodfill --hpc dug

if [[ "${skip_result_copy}" != "1" ]]; then
  ## copy the data over to storage
  scp ${obsnum}-dug-measurements.fits zeus:'/astro/mwasci/sprabu/rfiseekerLog'
fi

