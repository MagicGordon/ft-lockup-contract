#!/bin/bash
set -e

PROGRAM=$0
DECIMALS="000000000000000000"

HELP_TITLE="Usage:"
COMMOND="$PROGRAM { add_lockup | show_lockup | claim_lockup | balance } [args]"
SUBCOMMOND_ADD_LOCKUP="$PROGRAM add_lockup <ft_contract_id> <lockup_contract_id> <operation_account_id> <account_id> <amount> <release_time>"
SUBCOMMOND_SHOW_LOCKUP="$PROGRAM show_lockup <lockup_contract_id> <query_account_id>"
SUBCOMMOND_CLAIM_LOCKUP="$PROGRAM claim_lockup <lockup_contract_id> <operation_account_id>"
SUBCOMMOND_BALANCE="$PROGRAM balance <ft_contract_id> <query_account_id>"

info() { 
    echo -e "\033[32m$*\033[0m" 
}

error() { 
    echo -e "\033[31m$*\033[0m" 
}

help(){
    info $HELP_TITLE
    echo
    info $COMMOND
    echo
    info $SUBCOMMOND_ADD_LOCKUP
    info $SUBCOMMOND_SHOW_LOCKUP
    info $SUBCOMMOND_CLAIM_LOCKUP
    info $SUBCOMMOND_BALANCE
}

ft_balance_of(){
    FT_CONTRACT_NAME=$1
    QUERY_ACCOUNT=$2

    if [ "" = "$FT_CONTRACT_NAME" ] || [ "" = "$QUERY_ACCOUNT" ]; then
        error "[mising args] " $SUBCOMMOND_BALANCE
    else
        near view $FT_CONTRACT_NAME ft_balance_of '{"account_id": "'$QUERY_ACCOUNT'"}'
    fi
}

add_lockup(){
    LOCKUP_CONTRACT_NAME=$1
    FT_CONTRACT_NAME=$2
    OPERATION_ACCOUNT=$3
    ACCOUNT_ID=$4
    AMOUNT=$5
    RELEASE_TIME=$6

    if [ "" = "$LOCKUP_CONTRACT_NAME" ] || [ "" = "$FT_CONTRACT_NAME" ] || [ "" = "$OPERATION_ACCOUNT" ] || [ "" = "$ACCOUNT_ID" ] || [ "" = "$AMOUNT" ] || [ "" = "$RELEASE_TIME" ]; then
        error "[mising args] " $SUBCOMMOND_ADD_LOCKUP
    else
        BEGIN_TIMESTAMP=$[$RELEASE_TIME-1]

        near call $FT_CONTRACT_NAME storage_deposit '{"account_id": "'$ACCOUNT_ID'", "registration_only": true}' --accountId $OPERATION_ACCOUNT --amount 0.1
        near call $FT_CONTRACT_NAME storage_deposit '{"account_id": "'$LOCKUP_CONTRACT_NAME'", "registration_only": true}' --accountId $OPERATION_ACCOUNT --amount 0.1

        MSG_JSON_INPUT='{\"account_id\": \"'$ACCOUNT_ID'\", \"schedule\": [{\"timestamp\": '$BEGIN_TIMESTAMP', \"balance\": \"0\"}, {\"timestamp\": '$RELEASE_TIME', \"balance\": \"'$AMOUNT$DECIMALS'\"}]}'
        echo near call $FT_CONTRACT_NAME ft_transfer_call \'{\"receiver_id\": \"$LOCKUP_CONTRACT_NAME\", \"amount\": \"$AMOUNT$DECIMALS\", \"msg\": \"$MSG_JSON_INPUT\"}\' --accountId $OPERATION_ACCOUNT --amount 0.000000000000000000000001 --gas 100000000000000 | bash
    fi
}

show_lockup(){
    LOCKUP_CONTRACT_NAME=$1
    QUERY_ACCOUNT=$2

    if [ "" = "$LOCKUP_CONTRACT_NAME" ] || [ "" = "$QUERY_ACCOUNT" ]; then
        error "[mising args] " $SUBCOMMOND_SHOW_LOCKUP
    else
        near view $LOCKUP_CONTRACT_NAME get_account_lockups '{"account_id": "'$QUERY_ACCOUNT'"}'
    fi
}

claim_lockup(){
    LOCKUP_CONTRACT_NAME=$1
    OPERATION_ACCOUNT=$2

    if [ "" = "$LOCKUP_CONTRACT_NAME" ] || [ "" = "$OPERATION_ACCOUNT" ]; then
        error "[mising args] " $SUBCOMMOND_CLAIM_LOCKUP
    else
        near call $LOCKUP_CONTRACT_NAME claim --accountId $OPERATION_ACCOUNT --gas 100000000000000
    fi
}

main(){
    if [ "" = "$1" ]; then
        help
        exit 1
    fi
    COMMOND=$1
    shift
    ARGS=$*
    case "$COMMOND" in
        add_lockup) 
            info "[task]: add_lockup begin"
            add_lockup $ARGS
            info "[task]: add_lockup end"
            ;;
        show_lockup) 
            info "[task]: show_lockup begin"
            show_lockup $ARGS
            info "[task]: show_lockup end"
            ;;
        claim_lockup) 
            info "[task]: claim_lockup begin"
            claim_lockup $ARGS
            info "[task]: claim_lockup end"
            ;;
        balance)
            info "[task]: balance begin"
            ft_balance_of $ARGS
            info "[task]: balance end"
            ;;
        *)
            help
            exit 1
            ;;
    esac
}

main $*