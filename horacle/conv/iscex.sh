#!/usr/bin/env bash

export LC_COLLATE="C"
export LC_ALL="C"

SCRIPT_PATH=$(cd "$(dirname "$0")" ; pwd -P)

cd ${SCRIPT_PATH}

TMPFILE=$(mktemp -p ${SCRIPT_PATH})
FORMFILE="./forms${1}.csv"
ORACLEFILE="../../htest/oracle_reach${1}.txt"

sort -k 1b,1 ${FORMFILE} -o ${FORMFILE}
sort -k 1b,1 ${ORACLEFILE} -o ${ORACLEFILE}

join -j 1  -o 1.1,1.2,2.2  ${FORMFILE} ${ORACLEFILE} > ${TMPFILE}

while IFS="" read -r p || [ -n "$p" ]
do
  theline=($p)

  if [[ "${theline[1]}" == "AG" && "${theline[2]}" == "TRUE" ]]; then 
    printf '%s INV\n' "${theline[0]}"
  elif [[ "${theline[1]}" == "AG" && "${theline[2]}" == "FALSE" ]]; then 
    printf '%s CEX\n' "${theline[0]}"
  elif [[ "${theline[1]}" == "EF" && "${theline[2]}" == "TRUE" ]]; then 
    printf '%s CEX\n' "${theline[0]}"
  elif [[ "${theline[1]}" == "EF" && "${theline[2]}" == "FALSE" ]]; then 
    printf '%s INV\n' "${theline[0]}"
  else 
    printf '%s UNKNOWN\n' "${theline[0]}"
  fi
done < ${TMPFILE}

rm ${TMPFILE}
