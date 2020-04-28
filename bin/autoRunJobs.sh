#!/bin/bash

usage()
{
echo "autoSubmitJobs.sh [-c calibration] [-o obsnum] [-a account] [-f channels] [-s timeSteps]
        -c calibration          : path to calibration solution
        -a account              : pawsey Account to use
        -f channels             : the number of channels in ms, default=768
        -s timeSteps            : the number of timeSteps in ms, default=56
        -o obsnum               : the obsid" 1>&2;
exit 1;
}

calibrationPath=
account="mwasci"
channels=768
timeSteps=55
obsnum=

while getopts 'c:o:a:f:s:' OPTION
do
    case "$OPTION" in
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

## run cotter ##
script="${base}queue/cotter_${obsnum}.sh"
cat ${base}/bin/cotter.sh | sed -e "s:OBSNUM:${obsnum}:g" \
                                 -e "s:BASE:${base}:g" > ${script}
output="${base}queue/logs/cotter_${obsnum}.o%A"
error="${base}queue/logs/cotter_${obsnum}.e%A"
sub="sbatch --begin=now+15 --output=${output} --error=${error} -A ${account} ${script} -c ${calibrationPath} "
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



