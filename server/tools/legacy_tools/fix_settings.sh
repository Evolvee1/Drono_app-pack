#!/bin/bash
DEVICE_ID=$1
PACKAGE="com.example.imtbf.debug"
TARGET_URL="https://l.instagram.com/?u=https%3A%2F%2Fdyson-sk.mtpc.se%2F5305509%3Ffbclid%3DPAZXh0bgNhZW0CMTEAAae9cU1om-qtxUgSMM3SekltpV4Sai0bUQ9_Cd8rVDPLc9J7vJTUi4NUqcqJCw_aem_wEsehnLupPD2FBsIJ3bldA&e=AT0Btvg2c2OEqSpFlrQ3TXahMqFL25u4rzkr54i1O2Mo7bZbiOXJEOz09aifASkH0kmp39Rw_hKS59qtAW1l-S_8TrnA1F4Xl5wwuA"
adb -s $DEVICE_ID shell "am force-stop $PACKAGE"
sleep 2
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_url --es url \"$TARGET_URL\" -p $PACKAGE"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_option --es key use_webview_mode --ez value true -p $PACKAGE"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_option --es key new_webview_per_request --ez value true -p $PACKAGE"
adb -s $DEVICE_ID shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_option --es key restore_on_exit --ez value false -p $PACKAGE"
adb -s $DEVICE_ID shell "am start -n $PACKAGE/com.example.imtbf.presentation.activities.MainActivity -a android.intent.action.VIEW -d \"traffic-sim://instagram?url=$TARGET_URL&force=true\""
