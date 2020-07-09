#!/bin/bash

usage()
{
echo "autoSubmitJobs.sh [-c calibration] [-o obsnum] [-a account] [-f channels] [-s timeSteps] [-t target wget] [-q calibration obs] [-u calibration wget] [-m calibration model]
        -c calibration          : path to calibration solution
        -m calibration model    : the calibration model
        -a account              : pawsey Account to use
        -q calibration obs      : the obs id for calibration
        -u calibration wget     : the wget link for calibration obs
        -f channels             : the number of channels in ms, default=768
        -s timeSteps            : the number of timeSteps in ms, default=56
        -t target wget          : the asvo wget link for target obs
        -o obsnum               : the obsid" 1>&2;
exit 1;
}

calibrationPath=
account="mwasci"
channels=768
timeSteps=55
obsnum=
calibration_obs=
calibration_asvo=
calibration_model=
target_asvo=


while getopts 'c:o:a:f:s:t:q:u:m:' OPTION
do
    case "$OPTION" in
        m)
            calibration_model=${OPTARG}
            ;;
        u)
            calibration_asvo=${OPTARG}
            ;;
        q)
            calibration_obs=${OPTARG}
            ;;
        f)
            channels=${OPTARG}
            ;;
        s)
            timeSteps=${OPTARG}
            ;;
        c)
            calibrationPath=${OPTARG}
            ;;
        o)
            obsnum=${OPTARG}     
            ;;
        a)
            account=${OPTARG}
            ;;
        t)
            target_asvo=${OPTARG}
            ;;
        
        ? | : | h)
            usage
            ;;
    esac
done

# if obsid is empty then just pring help
if [[ -z ${obsnum} ]]
then
    usage
fi

base=/astro/mwasci/sprabu/satellites/DUG-MWA-SSA-Pipeline/


## run asvo for target obs ##
script="${base}queue/asvo_${obsnum}.sh"
cat ${base}/bin/cotter.sh | sed -e "s:OBSNUM:${obsnum}:g" \
                                 -e "s:BASE:${base}:g" > ${script}
output="${base}queue/logs/asvo_${obsnum}.o%A"
error="${base}queue/logs/asvo_${obsnum}.e%A"
sub="sbatch --begin=now+15 --output=${output} --error=${error} -A ${account} ${script} -l ${target_asvo} "
jobidasvo=($(${sub}))
jobidasvo=${jobidasvo[3]}
# rename the err/output files as we now know the jobid
error=`echo ${error} | sed "s/%A/${jobidasvo}/"`
output=`echo ${output} | sed "s/%A/${jobidasvo}/"`

echo "Submitted ASVO job for target obs as ${jobidasvo}"


## check if calibration sol exists
if [[ -e "${calibrationPath}" ]]
then
    echo "Calibration solution exists"

else
    echo "Calibration solution does NOT exist"

    ## asvo for calibration
    script="${base}queue/asvo_${calibration_obs}.sh"
    cat ${base}/bin/cotter.sh | sed -e "s:OBSNUM:${calibration_obs}:g" \
                                 -e "s:BASE:${base}:g" > ${script}
    output="${base}queue/logs/asvo_${calibration_obs}.o%A"
    error="${base}queue/logs/asvo_${calibration_obs}.e%A"
    sub="sbatch --begin=now+15 --output=${output} --error=${error} --dependency=afterok:${jobidasvo} -A ${account} ${script} -l ${calibration_asvo} "
    jobidasvo=($(${sub}))
    jobidasvo=${jobidasvo[3]}
    # rename the err/output files as we now know the jobid
    error=`echo ${error} | sed "s/%A/${jobidasvo}/"`
    output=`echo ${output} | sed "s/%A/${jobidasvo}/"`

    echo "Submitted ASVO job for calibration obs obs as ${jobidasvo}"


    ## calibration job for calibration
    script="${base}queue/calibrate_${calibration_obs}.sh"
    cat ${base}/bin/cotter.sh | sed -e "s:OBSNUM:${calibration_obs}:g" \
                                 -e "s:BASE:${base}:g" > ${script}
    output="${base}queue/logs/calibrate_${calibration_obs}.o%A"
    error="${base}queue/logs/calibrate_${calibration_obs}.e%A"
    sub="sbatch --begin=now+15 --output=${output} --error=${error} --dependency=afterok:${jobidasvo} -A ${account} ${script} -m ${calibration_model} "
    jobidasvo=($(${sub}))
    jobidasvo=${jobidasvo[3]}
    # rename the err/output files as we now know the jobid
    error=`echo ${error} | sed "s/%A/${jobidasvo}/"`
    output=`echo ${output} | sed "s/%A/${jobidasvo}/"`

    echo "Submitted calibration job as ${jobidasvo}"

fi



## run cotter ##
script="${base}queue/cotter_${obsnum}.sh"
cat ${base}/bin/cotter.sh | sed -e "s:OBSNUM:${obsnum}:g" \
                                 -e "s:BASE:${base}:g" > ${script}
output="${base}queue/logs/cotter_${obsnum}.o%A"
error="${base}queue/logs/cotter_${obsnum}.e%A"
sub="sbatch --begin=now+15 --output=${output} --error=${error} --dependency=afterok:${jobidasvo} -A ${account} ${script} -c ${calibrationPath} "
jobid1=($(${sub}))
jobid1=${jobid1[3]}
# rename the err/output files as we now know the jobid
error=`echo ${error} | sed "s/%A/${jobid1}/"`
output=`echo ${output} | sed "s/%A/${jobid1}/"`

echo "Submitted cotter job as ${jobid1}"


## run high res imaging ##
script="${base}queue/hrimage_${obsnum}.sh"
cat ${base}/bin/hrimage.sh | sed -e "s:OBSNUM:${obsnum}:g" \
                                 -e "s:BASE:${base}:g" > ${script}
output="${base}queue/logs/hrimage_${obsnum}.o%A"
error="${base}queue/logs/hrimage_${obsnum}.e%A"
sub="sbatch --begin=now+15 --output=${output} --error=${error} --dependency=afterok:${jobid1} -A ${account}  ${script} -s ${timeSteps} -f ${channels}"
jobid2=($(${sub}))
jobid2=${jobid2[3]}
# rename the err/output files as we now know the jobid
error=`echo ${error} | sed "s/%A/${jobid2}/"`
output=`echo ${output} | sed "s/%A/${jobid2}/"`

echo "Submitted hrimage job as ${jobid2}"



## run RFISeeker ##
script="${base}queue/rfiseeker_${obsnum}.sh"
cat ${base}/bin/rfiseeker.sh | sed -e "s:OBSNUM:${obsnum}:g" \
                                 -e "s:BASE:${base}:g" > ${script}
output="${base}queue/logs/rfiseeker_${obsnum}.o%A"
error="${base}queue/logs/rfiseeker_${obsnum}.e%A"
sub="sbatch --begin=now+15 --output=${output} --error=${error} -A ${account} --dependency=afterok:${jobid2} ${script} -s ${timeSteps} -f ${channels}"
jobid3=($(${sub}))
jobid3=${jobid3[3]}
### rename the err/output files as we now know the jobid
error=`echo ${error} | sed "s/%A/${jobid3}/"`
output=`echo ${output} | sed "s/%A/${jobid3}/"`
echo "Submitted RFISeeker job as ${jobid3}"


## run clear files job ##
script="${base}queue/clear_${obsnum}.sh"
cat ${base}/bin/clear.sh | sed -e "s:OBSNUM:${obsnum}:g" \
                                 -e "s:BASE:${base}:g" > ${script}
output="${base}queue/logs/clear_${obsnum}.o%A"
error="${base}queue/logs/clear_${obsnum}.e%A"
sub="sbatch --begin=now+15 --output=${output} --error=${error} -A ${account} --dependency=afterok:${jobid3} ${script}"
jobid4=($(${sub}))
jobid4=${jobid4[3]}
## rename the err/output files as we now know the jobid
error=`echo ${error} | sed "s/%A/${jobid4}/"`
output=`echo ${output} | sed "s/%A/${jobid4}/"`
echo "Submitter clear job as ${jobid4}"



