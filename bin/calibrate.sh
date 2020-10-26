#! /bin/bash -l
#rj nodes=1 runtime=2 name=calibrate

start=`date +%s`

source /p9/mcc_icrar/sw/env.sh

set -x 

{

while getopts 'm:' OPTION
do
    case "$OPTION" in
        c)
            calibrationModel=${OPTARG}
            ;;
    esac
done

calibrationModel=$(echo ${calibrationModel} | sed -E "s/=//g")
datadir=${base}/processing/${obsnum}

echo "calibrating for model ${calibrationModel}"
cd ${datadir}

## copy over the mwapy module
#cp -r /astro/mwasci/sprabu/satellites/mwapy .
SCRIPT_PATH=/p9/mcc_icrar/sw/bin
MODEL_PATH=${base}/model

# flag baselines in DATA column
aoflagger ${obsnum}.ms

# flag tile in DATA column
python ${SCRIPT_PATH}/tileFlagger.py --obs ${obsnum} --data_col DATA

# flag channels in DATA column
python ${SCRIPT_PATH}/freqFlag.py --obs ${obsnum} --col DATA

# round 1 calibration using source model
calibrate -absmem 120 -j 64 -m ${MODEL_PATH}/model-${calibrationModel}*withalpha.txt -minuv 150 ${obsnum}.ms round1_sol.bin

# apply round 1 solution to measurement set
applysolutions ${obsnum}.ms round1_sol.bin

# flag baselines in CORRECTED_DATA col
aoflagger ${obsnum}.ms

# flag channels in CORRECTED_DATA col
python ${SCRIPT_PATH}/freqFlag.py --obs ${obsnum} --col CORRECTED_DATA

# calibrate with the new flags and model
calibrate -absmem 120 -j 64 -m ${MODEL_PATH}/model-${calibrationModel}*withalpha.txt -minuv 150 ${obsnum}.ms round2_sol.bin

## interpolate calibration solution for flagged freq
python ${SCRIPT_PATH}/solInterpolate.py --inputFile round2_sol.bin --obs ${obsnum}

## applysolution
applysolutions ${obsnum}.ms ${obsnum}.bin

end=`date +%s`
runtime=$((end-start))
echo "the job run time ${runtime}"

}
