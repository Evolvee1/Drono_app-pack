adb -s $1 shell "am broadcast -a com.example.imtbf.debug.COMMAND --es command get_status -p com.example.imtbf.debug"
