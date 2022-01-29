#!/bin/bash
set -e

PROGRAM=$0
USER_NUM=5
DECIMALS="000000000000000000"
NEAR_DEV_FOLDER="./neardev"
NEAR_DEV_DEPOLY="near dev-deploy --wasmFile "

GLOBAL_LOCKUP_CONTRACT_NAME=""
GLOBAL_FT_CONTRACT_NAME=""

info() { 
    echo -e "\033[32m$*\033[0m" 
}

error() { 
    echo -e "\033[31m$*\033[0m" 
}

help(){
    TOKEN_TEMP_ID="dev-1643449555600-70033439958565"
    LOCKUP_TEMP_ID="dev-1643449620413-27670534046295"
    info "Usage:"
    info $PROGRAM" {init_token | init_lockup | add_lockup | show_lockup | claim_lockup | batch_lockup | balance} [args]"
    info $PROGRAM" init_token <wasm_file_path>"
    info $PROGRAM" init_lockup <wasm_file_path> <ft_contract_id> [whitelist]"
    info $PROGRAM" add_lockup <ft_contract_id> <lockup_contract_id> <whitelist_account_id> [account_id] [amount]"
    info $PROGRAM" show_lockup <lockup_contract_id> <ft_contract_id> [account_id]"
    info $PROGRAM" claim_lockup <lockup_contract_id> <ft_contract_id> [account_id]"
    info $PROGRAM" balance <ft_contract_id> [account_id]"
    info $PROGRAM" batch_lockup <ft_wasm_file_path> <lockup_wasm_file_path>"
    echo
    info "Example:"
    info $PROGRAM" init_token ./res/fungible_token.wasm"
    info $PROGRAM" init_lockup ./res/ft_lockup.wasm $TOKEN_TEMP_ID"
    info $PROGRAM" init_lockup ./res/ft_lockup.wasm $TOKEN_TEMP_ID \[\"01.$TOKEN_TEMP_ID\"\]"
    info $PROGRAM" add_lockup  $LOCKUP_TEMP_ID $TOKEN_TEMP_ID 01.$TOKEN_TEMP_ID 01.$TOKEN_TEMP_ID 100"
    info $PROGRAM" add_lockup  $LOCKUP_TEMP_ID $TOKEN_TEMP_ID 01.$TOKEN_TEMP_ID"
    info $PROGRAM" show_lockup $LOCKUP_TEMP_ID $TOKEN_TEMP_ID"
    info $PROGRAM" show_lockup $LOCKUP_TEMP_ID $TOKEN_TEMP_ID 01.$TOKEN_TEMP_ID"
    info $PROGRAM" claim_lockup $LOCKUP_TEMP_ID $TOKEN_TEMP_ID"
    info $PROGRAM" claim_lockup $LOCKUP_TEMP_ID $TOKEN_TEMP_ID 01.$TOKEN_TEMP_ID"
    info $PROGRAM" balance $TOKEN_TEMP_ID"
    info $PROGRAM" batch_lockup ./res/fungible_token.wasm ./res/ft_lockup.wasm"
}

remove_neardev(){
    if [ -d "$NEAR_DEV_FOLDER" ]; then
        rm -rf "$NEAR_DEV_FOLDER"
    fi
}

ft_balance_of(){
    if [ "" = "$2" ]; then
        for i in `seq $USER_NUM` 
        do  
            ACCOUNT=`printf "%02d\n" $i`.$1
            BALANCE=`near view $1 ft_balance_of '{"account_id": "'$ACCOUNT'"}' | cut -d ")" -f2`
            info [balance] $ACCOUNT: $BALANCE
        done
    else
        BALANCE=`near view $1 ft_balance_of '{"account_id": "'$2'"}' | cut -d ")" -f2`
        info [balance] $2: $BALANCE
    fi
}

init_token(){
    WASM_FILE_PATH=$1
    remove_neardev
    $NEAR_DEV_DEPOLY $WASM_FILE_PATH
    FT_CONTRACT_NAME=`cat neardev/dev-account.env | cut -d "=" -f2`
    JSON_INPUT='{"owner_id": "'$FT_CONTRACT_NAME'", "total_supply": "500000'$DECIMALS'", "metadata": { "spec": "ft-1.0.0", "name": "ref", "symbol": "EXLT", "decimals": 18}}'
    echo near call $FT_CONTRACT_NAME new \'$JSON_INPUT\' --accountId $FT_CONTRACT_NAME | bash
    for i in `seq $USER_NUM` 
    do  
        ACCOUNT=`printf "%02d\n" $i`.$FT_CONTRACT_NAME
        near create-account $ACCOUNT --masterAccount $FT_CONTRACT_NAME --initialBalance 1
        near call $FT_CONTRACT_NAME storage_deposit '' --accountId $ACCOUNT --amount 0.00125
    done
    GLOBAL_FT_CONTRACT_NAME=$FT_CONTRACT_NAME
}

init_lockup(){
    WASM_FILE_PATH=$1
    FT_CONTRACT_NAME=$2
    WHITE_LIST=$3
    remove_neardev
    $NEAR_DEV_DEPOLY $WASM_FILE_PATH
    LOCKUP_CONTRACT_NAME=`cat neardev/dev-account.env | cut -d "=" -f2`
    JSON_INPUT='{"token_account_id": "'$FT_CONTRACT_NAME'", "deposit_whitelist": ["'01.$FT_CONTRACT_NAME'"]}'
    if [ "" != "$WHITE_LIST" ];then
        JSON_INPUT='{"token_account_id": "'$FT_CONTRACT_NAME'", "deposit_whitelist": '$WHITE_LIST'}'
    fi
    echo near call $LOCKUP_CONTRACT_NAME new \'$JSON_INPUT\' --accountId $LOCKUP_CONTRACT_NAME | bash
    near call $FT_CONTRACT_NAME storage_deposit '' --accountId $LOCKUP_CONTRACT_NAME --amount 0.00125
    near call $FT_CONTRACT_NAME ft_transfer '{"receiver_id": "'01.$FT_CONTRACT_NAME'", "amount": "20000'$DECIMALS'"}' --accountId $FT_CONTRACT_NAME --amount 0.000000000000000000000001
    GLOBAL_LOCKUP_CONTRACT_NAME=$LOCKUP_CONTRACT_NAME
}

add_lockup(){
    LOCKUP_CONTRACT_NAME=$1
    FT_CONTRACT_NAME=$2
    WHITE_LIST_ACCOUNT=$3
    ACCOUNT_ID=$4
    AMOUNT=$5

    CURRENT_TIMESTAMP=`date '+%s'`
    ADD_TIME=180
    END_TIMESTAMP=$[$CURRENT_TIMESTAMP+$ADD_TIME]
    BEGIN_TIMESTAMP=$[$END_TIMESTAMP-1]

    if [ "" = "$ACCOUNT_ID" ];then
        for i in `seq $USER_NUM` 
        do  
            ACCOUNT=`printf "%02d\n" $i`.$FT_CONTRACT_NAME
            MSG_JSON_INPUT='{\"account_id\": \"'$ACCOUNT'\", \"schedule\": [{\"timestamp\": '$BEGIN_TIMESTAMP', \"balance\": \"0\"}, {\"timestamp\": '$END_TIMESTAMP', \"balance\": \"100'$DECIMALS'\"}]}'
            echo near call $FT_CONTRACT_NAME ft_transfer_call \'{\"receiver_id\": \"$LOCKUP_CONTRACT_NAME\", \"amount\": \"100$DECIMALS\", \"msg\": \"$MSG_JSON_INPUT\"}\' --accountId $WHITE_LIST_ACCOUNT --amount 0.000000000000000000000001 --gas 100000000000000 | bash
        done
    else
        MSG_JSON_INPUT='{\"account_id\": \"'$ACCOUNT_ID'\", \"schedule\": [{\"timestamp\": '$BEGIN_TIMESTAMP', \"balance\": \"0\"}, {\"timestamp\": '$END_TIMESTAMP', \"balance\": \"'$AMOUNT$DECIMALS'\"}]}'
        echo near call $FT_CONTRACT_NAME ft_transfer_call \'{\"receiver_id\": \"$LOCKUP_CONTRACT_NAME\", \"amount\": \"$AMOUNT$DECIMALS\", \"msg\": \"$MSG_JSON_INPUT\"}\' --accountId $WHITE_LIST_ACCOUNT --amount 0.000000000000000000000001 --gas 100000000000000 | bash
    fi
}

show_lockup(){
    LOCKUP_CONTRACT_NAME=$1
    FT_CONTRACT_NAME=$2
    SPECIFIDED_ACCOUNT=$3
    if [ "" = "$SPECIFIDED_ACCOUNT" ]; then
        for i in `seq $USER_NUM` 
        do  
            ACCOUNT=`printf "%02d\n" $i`.$FT_CONTRACT_NAME
            LOCKUP=`near view $LOCKUP_CONTRACT_NAME get_account_lockups '{"account_id": "'$ACCOUNT'"}'`
            info [lockup] $ACCOUNT: 
            info $LOCKUP
            echo
        done
    else
        LOCKUP=`near view $LOCKUP_CONTRACT_NAME get_account_lockups '{"account_id": "'$SPECIFIDED_ACCOUNT'"}'`
        info [lockup] $SPECIFIDED_ACCOUNT: 
        info $LOCKUP
    fi
}

claim_lockup(){
    LOCKUP_CONTRACT_NAME=$1
    FT_CONTRACT_NAME=$2
    SPECIFIDED_ACCOUNT=$3
    if [ "" = "$SPECIFIDED_ACCOUNT" ]; then
        for i in `seq $USER_NUM`
        do  
            ACCOUNT=`printf "%02d\n" $i`.$FT_CONTRACT_NAME
            near call $LOCKUP_CONTRACT_NAME claim --accountId $ACCOUNT --gas 100000000000000
        done
    else
        near call $LOCKUP_CONTRACT_NAME claim --accountId $SPECIFIDED_ACCOUNT --gas 100000000000000
    fi
}

batch_lockup(){
    info [ JOB ] ">>>" init_token begin
    init_token $1
    info [ JOB ] "<<<" init_token end

    info [ JOB ] ">>>" init_lockup begin
    init_lockup $2 $GLOBAL_FT_CONTRACT_NAME
    info [ JOB ] "<<<" init_lockup end

    info [ JOB ] ">>>" add_lockup begin
    add_lockup $GLOBAL_LOCKUP_CONTRACT_NAME $GLOBAL_FT_CONTRACT_NAME 01.$GLOBAL_FT_CONTRACT_NAME
    info [ JOB ] "<<<" add_lockup end

    info [ JOB ] ">>>" show_lockup begin
    show_lockup $GLOBAL_LOCKUP_CONTRACT_NAME $GLOBAL_FT_CONTRACT_NAME
    info [ JOB ] "<<<" show_lockup end

    info [ JOB ] ">>>" ft_balance_of begin
    ft_balance_of $GLOBAL_FT_CONTRACT_NAME
    info [ JOB ] "<<<" ft_balance_of end

    info [ JOB ] ">>>" claim_lockup begin
    claim_lockup $GLOBAL_LOCKUP_CONTRACT_NAME $GLOBAL_FT_CONTRACT_NAME
    info [ JOB ] "<<<" claim_lockup end

    info [ JOB ] ">>>" ft_balance_of again begin
    ft_balance_of $GLOBAL_FT_CONTRACT_NAME
    info [ JOB ] "<<<" ft_balance_of again end

    info [contract_name] lockup $GLOBAL_LOCKUP_CONTRACT_NAME
    info [contract_name] token  $GLOBAL_FT_CONTRACT_NAME
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
        init_token) 
            info "[task]: init_token begin"
            init_token $ARGS
            info "[task]: init_token end"
            ;;
        init_lockup) 
            info "[task]: init_lockup begin"
            init_lockup $ARGS
            info "[task]: init_lockup end"
            ;;
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
        batch_lockup) 
            info "[task]: batch_lockup begin"
            batch_lockup $ARGS
            info "[task]: batch_lockup end"
            ;;
        claim_lockup) 
            info "[task]: claim_lockup begin"
            claim_lockup $ARGS
            info "[task]: claim_lockup end"
            ;;
        balance)
            info "[task]: ft_balance_of begin"
            ft_balance_of $ARGS
            info "[task]: ft_balance_of end"
            ;;
        *)
            help
            exit 1
            ;;
    esac
}

main $*