#!/bin/bash

### CONSTANTS

CONFIG_DIR="$HOME/.otp-gen"
CONFIG_DB_NAME="otp-gen.sqlite"
CONFIG_DB="$CONFIG_DIR/$CONFIG_DB_NAME"


### FUNCTIONS

init()
{
    # make the config directory
    [ ! -d $CONFIG_DIR ] && mkdir $CONFIG_DIR

    # make the database
    if [ ! -f $CONFIG_DB ] 
    then
        sqlite3 $CONFIG_DB "CREATE TABLE otp_info ( name VARCHAR(50) UNIQUE, pin VARCHAR(50), key VARCHAR(50), count INT);"
        chmod 600 $CONFIG_DB
    fi
}

usage ()
{
    echo "usage:  $0 add NAME PIN KEY [ INITIAL_COUNT ]  # add new OTP (replaces existing)"
    echo "        $0 remove NAME                     # remove an existing OTP"
    echo "        $0 generate NAME                   # generate a password"
    echo "        $0 usage | --help                  # print usage and exit"
    echo ""
    echo "NAME is the identifier of the OTP you wish to add, remove or generate"
    echo "PIN is the text that will be prefixed to the generated OTP"
    echo "KEY is the secret key used to see the OTP algorithm"
    echo "INITIAL_COUNT is the count to store if you are reusing an existing HOTP key"
    echo ""
    echo "otp-gen will store the generated password on the user's clipboard. If NAME"
    echo "is not found when generating, the clipboard will be cleared and exit code"
    echo "will be 2."
}


### MAIN
case $1 in
    add )               if [ "$4" = "" ]
                        then
                            usage
                            exit 1
                        fi
                        init
                        initial_count=0
                        if [ "$5" != "" ]
                        then
                            initial_count=$5
                        fi
                        sqlite3 $CONFIG_DB "REPLACE INTO otp_info VALUES (\"$2\", \"$3\", \"$4\", $initial_count);" 
                        echo "added/replaced OTP entry $2 with key $4 and initial count $initial_count"
                        exit
                        ;;
    remove )            if [ "$2" = "" ]
                        then
                            usage
                            exit 1
                        fi
                        init
                        sqlite3 $CONFIG_DB "DELETE FROM otp_info WHERE name IS \"$2\";"
                        echo "removed OTP entry with name $2"
                        exit
                        ;;
    generate )          if [ "$2" = "" ]
                        then
                            usage
                            exit 1
                        fi
                        init
                        gen_pass=""
                        val=`sqlite3 $CONFIG_DB "SELECT * FROM otp_info WHERE name IS \"$2\" LIMIT 1;"`
                        if [ ! -z $val ]
                        then
                            key="$(cut -d'|' -f3 <<<$val)"
                            pin="$(cut -d'|' -f2 <<<$val)"
                            count="$(cut -d'|' -f4 <<<$val)"
                            token=$(oathtool -c ${count} ${key})
                            gen_pass="$pin$token"
                            sqlite3 $CONFIG_DB "UPDATE otp_info SET count = count + 1 WHERE name IS \"$2\";"
                        fi

                        case `uname -s` in
                            Linux* )
                                # Copy to GUI buffer (ib) and CLI buffer (ip)
                                echo -n $gen_pass | xsel -ib
                                echo -n $gen_pass | xsel -ip
                                ;;
                            Darwin* )
                                # The 'pbcopy' command is for OS X
                                echo -n $gen_pass | pbcopy
                                ;;
                            * )
                                ;;
                        esac
                        
                        if [ "$gen_pass" = "" ]
                        then
                            exit 2
                        fi
                        exit
                        ;;
    usage | --help )    usage
                        exit
                        ;;
    * )                 usage
                        exit 1
esac
exit
