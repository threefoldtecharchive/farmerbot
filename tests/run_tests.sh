#/bin/bash

SOURCE=${BASH_SOURCE[0]}
DIR_OF_THIS_SCRIPT="$( dirname "$SOURCE" )"
ABS_DIR_OF_SCRIPT="$( realpath $DIR_OF_THIS_SCRIPT )"

v -stats test $ABS_DIR_OF_SCRIPT/farmmanager_test.v
v -stats test $ABS_DIR_OF_SCRIPT/nodemanager_test.v
v -stats test $ABS_DIR_OF_SCRIPT/powermanager_test.v

