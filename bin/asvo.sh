#! /bin/bash -l
#rj nodes=1 runtime=1
export http_proxy='proxy.per.dug.com:3128'

set -x
function urldecode() { : "${*//+/ }"; echo -e "${_//%/\\x}"; }

#link=

while getopts 'l:' OPTION
do
    case "$OPTION" in
        l)
            link="${OPTARG}"
            ;;
    esac
done
link=$(urldecode "${link}")

echo "The download link is ${link}"

datadir=${base}/processing


cd ${datadir}
rm -rf ${obsnum}
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


#rm *.zip
set -e
wget -t 3 -nv -O ${obsnum}_ms.zip --no-check-certificate "${link}"


if [[ -e "${outfile}" ]]
then
    unzip -n ${outfile}
    rm ${outfile}
else
    echo "Failed to download ${outfile}!"
    exit 1
fi
