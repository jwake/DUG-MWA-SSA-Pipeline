#! /bin/bash -l
#rj nodes=1 runtime=1

set -x

{

link=

while getopts 'l:' OPTION
do
    case "$OPTION" in
        l)
            link=${OPTARG}
            ;;
    esac
done

echo "The download link is ${link}"

datadir=${base}processing


cd ${datadir}
rm -r ${obsnum}
mkdir -p ${obsnum}
cd  ${obsnum}

outfile="${obsnum}_ms.zip"
msfile="${obsnum}.ms"

if [[ -e "${outfile}" ]]
then
    echo "${outfile} exists, removing it..."
    rm -r ${outfile}
fi

if [[ -e "${msfile}" ]]
then
    echo "${msfile} exists, removing it..."
    rm -r ${msfile}
fi


rm *.zip
wget -O ${obsnum}_ms.zip --no-check-certificate "${link}"


if [[ -e "${outfile}" ]]
then
    unzip -n ${outfile}
    rm ${outfile}
fi

}
