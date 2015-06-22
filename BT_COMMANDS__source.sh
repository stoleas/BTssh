#!/bin/bash

C=(
    $'\e[1;31m' # RED
    $'\e[1;32m' # GREEN
    $'\e[0m'    # RESET
  )

zzDISPLAY_PCT_STATUS()
{
  ###########################
  # Script Required Variables
  ###########################
  CHARS_ESC_LBRACKET=${CHARS_ESC_LBRACKET:-$( printf "\e[" )}
  CHARS_NEW_LINE="\n"
  CLEAR_LINE_TEMPLATE=${CHARS_NEW_LINE}${CHARS_ESC_LBRACKET}A${CHARS_ESC_LBRACKET}K
  CLEAR_LINE=${CLEAR_LINE_TEMPLATE//500/${COLUMNS:-80}}
  DPS_COLOR_BASE=${CHARS_ESC_LBRACKET}"X;Ym"
  DPS_COLOR_RESET=${DPS_COLOR_BASE//X;Y/0}
  DPS_COLOR_BY_PCT=(  #   RED       #  Yellow    # LIGHT-BLUE   #   GREEN
                      [25]="1;31"   [50]="1;33"  [75]="1;36"    [100]="1;32"
                   )


  ###########################
  # LAST Variables
  ###########################
  DPS_LAST_VALUE[0]=${DPS_CUR_VALUE[0]:--1}
  DPS_LAST_VALUE[1]=${DPS_CUR_VALUE[1]:--1}
  DPS_LAST_MAX_VALUE=${DPS_MAX_VALUE:--1}
  DPS_LAST_PCT_VALUE[0]=${DPS_PCT_VALUE[0]:--1}
  DPS_LAST_PCT_VALUE[1]=${DPS_PCT_VALUE[1]:--1}
  DPS_LAST_FRAME_SECONDS=${DPS_CUR_FRAME_SECONDS:-${SECONDS:-0}}

  ###########################
  # User Input Variables
  ###########################
  DPS_CUR_VALUE=${1:-${DPS_LAST_VALUE}}
  DPS_MAX_VALUE=${2:-${DPS_LAST_MAX_VALUE}}
  if [ $(( DPS_CUR_VALUE )) -gt $(( DPS_MAX_VALUE )) ]
  then  DPS_CUR_VALUE=${DPS_MAX_VALUE}
  fi
  DPS_ZEROS=0${DPS_MAX_VALUE}000
  DPS_REPORT_ONLY_ON_PCT_CHANGE=${3:-1}


  ###########################
  # Variable Abuse
  ###########################
  DPS_CUR_FRAME_SECONDS=${SECONDS}
  DPS_PCT_VALUE=$(( 9${DPS_MAX_VALUE//[^9]/9}999 / DPS_MAX_VALUE * DPS_CUR_VALUE ))
  DPS_PCT_VALUE=${DPS_ZEROS:0:${#DPS_ZEROS} - ${#DPS_PCT_VALUE}}${DPS_PCT_VALUE}
  DPS_PCT_VALUE=${DPS_PCT_VALUE:0:4}

  if    [ "${DPS_PCT_VALUE:0:3}" == "000" ]
  then  DPS_PCT_VALUE[1]=0
  elif  [ "${DPS_PCT_VALUE:0:2}" == "00" ]
  then  DPS_PCT_VALUE[1]=0
  elif  [ "${DPS_PCT_VALUE:0:1}" == "0" ]
  then  DPS_PCT_VALUE[1]=${DPS_PCT_VALUE:1:1}
  else  DPS_PCT_VALUE[1]=${DPS_PCT_VALUE:0:2}
  fi

  if    [ "${DPS_CUR_VALUE}" != "${DPS_MAX_VALUE}" ]
  then
        DPS_PCT_VALUE[1]=${DPS_PCT_VALUE[1]:0:2}
        DPS_PCT_VALUE[2]=${DPS_PCT_VALUE:0:2}
  else
        DPS_PCT_VALUE[1]=100
        DPS_PCT_VALUE[2]=100
  fi

  if    [ ${DPS_REPORT_ONLY_ON_PCT_CHANGE:=1} -eq 1  ] && [ "${DPS_LAST_PCT_VALUE[1]}" == "${DPS_PCT_VALUE[1]}" ]
  then
        DPS_FRAMES_SKIPPED=$(( ${DPS_FRAMES_SKIPPED:-0} + 1 ))
        return 0
  else
        DPS_FRAMES_NOT_SKIPPED=$(( ${DPS_FRAMES_NOT_SKIPPED:-0} + 1 ))
  fi

  for DPS_PCT_COLOR in ${!DPS_COLOR_BY_PCT[*]} ; do 
      if    [ ${DPS_PCT_VALUE[1]} -le ${DPS_PCT_COLOR} ]
      then  break
      fi
  done

  if    [ "${DPS_LAST_PCT_VALUE[1]}" != "${DPS_PCT_VALUE[1]}" ]
  then
        DPS_START_TIME_BY_PERCENT[${DPS_PCT_VALUE[1]} + 1 ]=${SECONDS}
        DPS_END_TIME_BY_PERCENT[${DPS_PCT_VALUE[1]}]=${SECONDS}
  fi

  ###########################
  # Print Status
  ###########################
  CUR_POS=( "-" "\\" "|" "/" )
  printf  "${CLEAR_LINE}${DPS_COLOR_BASE//X;Y/${DPS_COLOR_BY_PCT[${DPS_PCT_COLOR}]}}" >&2
  printf  " ${CUR_POS[zzDISP_POS]:-   } Processing ${DPS_PCT_VALUE[1]}%% ( ${DPS_CUR_VALUE} / ${DPS_MAX_VALUE} pid: $$ )"
  printf  "${DPS_COLOR_RESET}" >&2
}




###########################
# BT_COMMANDS_ADD
###########################
# This function is used for adding new BT commands
# 
# EXAMPLE:
# BT_COMMANDS_ADD "echo 1"
# BT_COMMANDS_ADD "echo 2"
#
# These commands then get saved in BT_COMMANDS_IN variable
BT_COMMANDS_ADD()
{
  while [ ${#*} -ne 0 ] ; do
        BT_COMMANDS_IN[${#BT_COMMANDS_IN[@]}]=${1} ; shift
  done
}

###########################
# BT_COMMANDS_SHOW
###########################
# This function shows all the values set in BT_COMMANDS_IN variable
# 
# EXAMPLE OUTPUT
## BT_COMMANDS_IN[0]
#  echo 1
#
## BT_COMMANDS_IN[1]
#  echo 2
BT_COMMANDS_SHOW()
{
  for BT_COMMAND_INDEX in ${!BT_COMMANDS_IN[@]} ; do
      printf "%s\n" "# BT_COMMANDS_IN[${BT_COMMAND_INDEX}]" "  ${BT_COMMANDS_IN[BT_COMMAND_INDEX]}" ""
  done
}

###########################
# BT_COMMANDS_RESET
###########################
# Resets all commands currently added in BT_COMMANDS_IN
BT_COMMANDS_RESET()
{
  unset BT_COMMANDS_IN
}

###########################
# BT_COMMANDS_EXECUTE
###########################
# Executes the commands that are in the BT_COMMANDS_IN variable.
BT_COMMANDS_EXECUTE()
{
  GET_DATE=( $(date +%s) )
  # Gets the number of processors, if fails to find /proc/cpuinfo
  # sets the value of GET_PROCS to 1
  GET_PROCS=$( grep -c "^$" /proc/cpuinfo 2>/dev/null ) || GET_PROCS="1"
  GET_LIMIT=$( ulimit -u 2>/dev/null )                  || GET_LIMIT=512

  # Sets the number of max threads and multiplies it if BT_THREADS_MAX
  # is already not already set
  BT_THREADS_MULTIPLIER=2
  BT_THREADS_MAX=${BT_THREADS_MAX:-$(( GET_PROCS * BT_THREADS_MULTIPLIER ))}
  [ ${BT_THREADS_MAX} -ge ${GET_LIMIT} ] && BT_THREADS_MAX=$(( GET_LIMIT - 1 ))

  #
  BT_SLEEP_TIME=${BT_SLEEP_TIME:-$(sleep .001 && echo .001 || echo 1)}

  #
  rm -f /tmp/${USER}.$$.THREAD.*.log /tmp/${USER}.$$.THREAD.*.err 2>/dev/null

  unset BT_THREADS_CUR
  BT_COMMAND_INDEX=0
  zzDISP_POS=0

  (
    while [ ${BT_COMMAND_INDEX} -lt ${#BT_COMMANDS_IN[@]} ] || [ ${#BT_THREADS_CUR[@]} -gt 0 ] ; do
          if    [ ${#BT_THREADS_CUR[@]} -lt ${BT_THREADS_MAX:-4} ] && [ ${BT_COMMAND_INDEX} -lt ${#BT_COMMANDS_IN[@]} ]
          then
                LOG_FILE=( /tmp/${USER}.$$.THREAD.${BT_COMMAND_INDEX}.{log,err} )
                touch "${LOG_FILE[0]}" "${LOG_FILE[1]}" && chmod 600  "${LOG_FILE[0]}" "${LOG_FILE[1]}"
                eval "( ${BT_COMMANDS_IN[${BT_COMMAND_INDEX}]} ) 2>>\"${LOG_FILE[1]}\"  1>>\"${LOG_FILE[0]}\"" &
                THREAD_PID=$!
                BT_THREADS_CUR[THREAD_PID]=${BT_COMMANDS_IN[BT_COMMAND_INDEX]}
                BT_COMMAND_INDEX=$(( BT_COMMAND_INDEX + 1 ))
          else
                for THREAD_PID in ${!BT_THREADS_CUR[@]} ; do
                    [ ! -d /proc/${THREAD_PID} ] && unset BT_THREADS_CUR[${THREAD_PID}]
                done
          fi
          zzDISPLAY_PCT_STATUS $(( BT_COMMAND_INDEX + 1 )) ${#BT_COMMANDS_IN[@]} 0 >&2
          printf " %s" "${#BT_THREADS_CUR[@]}/${BT_THREADS_MAX} threads utilized" >&2
          zzDISP_POS=$(( zzDISP_POS + 1 )) ; [ ${zzDISP_POS} -eq ${#CUR_POS[@]} ] && zzDISP_POS=0
          #sleep ${BT_SLEEP_TIME:-1}
    done
  )
  GET_DATE+=( $(date +%s) )
  printf "\n\n" >&2
  BT_COMMAND_INDEX=0
  (
    while [ ${BT_COMMAND_INDEX} -lt ${#BT_COMMANDS_IN[@]} ] ; do
          LOG_FILE=( /tmp/${USER}.$$.THREAD.${BT_COMMAND_INDEX}.{log,err} )
          if    [ -s "${LOG_FILE[1]}" ]
          then  printf "# BT_COMMANDS_IN[${BT_COMMAND_INDEX}]: %-$((20-${#BT_COMMAND_INDEX}))s{C[0]}[FAILED]${C[1]}\n### OK ###\n"
                cat /tmp/${USER}.$$.THREAD.${BT_COMMAND_INDEX}.log
                printf "${C[0]}### ERROR ###\n"
                cat /tmp/${USER}.$$.THREAD.${BT_COMMAND_INDEX}.err >&2
                echo "${C[2]}"
                OUTCOME_COUNT[1]=$(( ${OUTCOME_COUNT[1]} + 1 ))
          else  printf "# BT_COMMANDS_IN[${BT_COMMAND_INDEX}]: %-$((20-${#BT_COMMAND_INDEX}))s${C[1]}[PASSED]${C[2]}\n"
                cat /tmp/${USER}.$$.THREAD.${BT_COMMAND_INDEX}.log
                echo ''
                OUTCOME_COUNT[0]=$(( ${OUTCOME_COUNT[0]} + 1 ))
          fi
          rm  /tmp/${USER}.$$.THREAD.${BT_COMMAND_INDEX}.[le][or][gr] 2>/dev/null
          BT_COMMAND_INDEX=$(( BT_COMMAND_INDEX + 1 ))
    done
    printf "#%.0s" {0..80} ; printf "\n# RESULTS\n" ; printf "#%.0s" {0..80} ; printf "\n"
    printf "#\n#%10sPassed: ${C[1]}${OUTCOME_COUNT[0]}${C[2]}\n#%10sFailed: ${C[0]}${OUTCOME_COUNT[1]}${C[2]}\n#\n#%11sStart: $(date -d @${GET_DATE[0]})\n#%13sEnd: $(date -d @${GET_DATE[1]})\n# Seconds Elapsed: $((${GET_DATE[1]}-${GET_DATE[0]}))\n#\n"
  )
  unset GET_DATE
}

