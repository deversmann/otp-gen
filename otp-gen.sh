#!/bin/bash

set -e #abort on error

### CONSTANTS

CONFIG_DIR="$HOME/.otp-gen"
CONFIG_DB_NAME="otp-gen.sqlite"
CONFIG_DB="$CONFIG_DIR/$CONFIG_DB_NAME"


### GLOBALS

mode=""
name=""
pin=""
key=""
counter=0
unknown=()


### FUNCTIONS

parse_args()
{
    while [[ $# -gt 0 ]]
    do
        case $1 in
            -h | --help )
                usage
                exit
                ;;
            add | remove | generate )
                if [ ! -z $mode ]
                then
                    echo "error - multiple modes specified" >&2
                    usage
                    exit 1
                fi
                mode=$1
                shift
                ;;
            -n | --name )
                name=$2
                shift 2
                ;;
            -n=* | --name=* )
                name=${1#*=}
                shift
                ;;
            -p | --pin )
                pin=$2
                shift 2
                ;;
            -p=* | --pin=* )
                pin=${1#*=}
                shift
                ;;
            -k | --key )
                key=$2
                shift 2
                ;;
            -k=* | --key=* )
                key=${1#*=}
                shift
                ;;
            -c | --counter )
                counter=$2
                shift 2
                ;;
            -c=* | --counter=* )
                counter=${1#*=}
                shift
                ;;
            * )
                unknown+=($1)
                shift
        esac
    done
    if [ ${#unknown[@]} -gt 0 ]
    then
        echo "error - unknown arguments: ${unknown[@]}" >&2
        usage
        exit 1
    fi
}

init()
{
    # make the config directory
    [ ! -d $CONFIG_DIR ] && mkdir $CONFIG_DIR

    # make the database
    if [ ! -f $CONFIG_DB ] 
    then
        sqlite3 $CONFIG_DB "CREATE TABLE otp_info ( name VARCHAR(50) UNIQUE, pin VARCHAR(50), key VARCHAR(50), count INT );"
        chmod 600 $CONFIG_DB
    fi
}

usage()
{
prog=${0##*/}
cat<<USAGE
usage:  $prog add -n NAME -p PIN -k KEY [ -c COUNTER ]  # add new OTP (replaces existing)
        $prog remove -n NAME                            # remove an existing OTP
        $prog generate -n NAME                          # generate a password
        $prog -h | --help                               # print usage and exit

NAME is the identifier of the OTP you wish to add, remove or generate
PIN is the text that will be prefixed to the generated OTP
KEY is the secret key used to see the OTP algorithm
COUNTER is the count to store if you are reusing an existing HOTP key

otp-gen will store the generated password on the user's clipboard. If NAME
is not found when generating, the clipboard will be cleared and exit code
will be 2.
USAGE
}

add() {
    if [ -z $name -o -z $pin -o -z $key ]
    then
        echo "error - name, pin and key are all required for add mode" >&2
        usage
        exit 1
    fi
    init
    sqlite3 $CONFIG_DB "REPLACE INTO otp_info VALUES (\"$name\", \"$pin\", \"$key\", $counter);" 
    echo "added/replaced OTP entry $name with key $key and initial count $counter"
}

remove() {
    if [ -z $name ]
    then
        echo "error - name is a required field for remove mode" >&2
        usage
        exit 1
    fi
    init
    sqlite3 $CONFIG_DB "DELETE FROM otp_info WHERE name IS \"$name\";"
    echo "removed OTP entry with name $name"
}

generate() {
    if [ -z $name ]
    then
        echo "error - name is a required field for generate mode" >&2
        usage
        exit 1
    fi
    init
    gen_pass=""
    val=`sqlite3 $CONFIG_DB "SELECT * FROM otp_info WHERE name IS \"$name\" LIMIT 1;"`
    if [ ! -z "$val" ] # entry for name exists
    then
        key="$(cut -d'|' -f3 <<<$val)"
        pin="$(cut -d'|' -f2 <<<$val)"
        count="$(cut -d'|' -f4 <<<$val)"
        token=$(oathtool -c ${count} ${key})
        gen_pass="$pin$token"
        sqlite3 $CONFIG_DB "UPDATE otp_info SET count = count + 1 WHERE name IS \"$name\";"
    fi

    case `uname -s` in
        Linux* )
            # Copy to GUI buffer (ib) and CLI buffer (ip)
            echo -n $gen_pass | xsel -ib
            echo -n $gen_pass | xsel -ip
            ;;
        Darwin* ) # Mac OSX
            # The 'pbcopy' command is for OS X
            echo -n $gen_pass | pbcopy
            ;;
        * )
            ;;
    esac

    if [ -z $gen_pass ]
    then
        echo "error - no entry found for $name - clipboard cleared"
        exit 2
    fi
}


### MAIN
parse_args "$@"
case $mode in
    add ) add ;;
    remove ) remove ;;
    generate ) generate ;;
esac
exit
