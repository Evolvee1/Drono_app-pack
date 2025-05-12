#!/bin/bash
adb -s $1 shell "am force-stop com.example.imtbf.debug" && sleep 1
adb -s $1 shell "am start -n com.example.imtbf.debug/com.example.imtbf.presentation.activities.MainActivity -a android.intent.action.VIEW -d \"traffic-sim://instagram?url=$2&force=true\""
adb -s $1 shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_option --es key use_webview_mode --ez value true -p com.example.imtbf.debug"
adb -s $1 shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_option --es key new_webview_per_request --ez value true -p com.example.imtbf.debug"
adb -s $1 shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command set_option --es key restore_on_exit --ez value false -p com.example.imtbf.debug"
adb -s $1 shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command start -p com.example.imtbf.debug"
