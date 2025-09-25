#!/usr/bin/env bash

# Program Requirement (debian base) others may has different packages name
# DEP: socat, bc, jq, build-essential libinput-dev libudev-dev 
# APP: mpv, wofi or others app you want to try..
# DE: Currently on sway/wayland, i3/x11 still have problem with mpv transparent background, And in hyprland not tested yet but been added some potential support
# For input base anim need to add input group in debian ` sudo usermod -aG input $USER `

# Build Check
REQUIRED_COMMANDS=("mpv" "bc" "jq" "socat")

for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: Required command '$cmd' is not installed."
        echo "Please install it and try again."
        exit 1
    fi
done
echo "Build checked: pass"

SOCK="/tmp/mpv_socket"
PIPE="/tmp/input_key.txt"
LOCKFILE="/tmp/anim_cooldown.lock"
EXIT_STATE="/tmp/funcer_exit_$$"
LAST_KEY="/tmp/last_key.txt"
MAIN_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)
KEY_LISTEN="$MAIN_DIR/scripts/keyboard_listener"
MPV_STARTUP="$MAIN_DIR/mpv_startup.sh"

READER_PID=""
INPUT_PID=""
LAUNCHER_PID=""
WINDOW_PID=""

# CONFIG FILE
CONFIG=$MAIN_DIR/config/config.json

# Options
RUN_KEY_LISTEN=0
while getopts "c:k" opt; do
	case $opt in
		c) CONFIG="$OPTARG" ;;
		k) RUN_KEY_LISTEN=1 ;;

		*) echo "Usage: $0 <OPTION> <ARGUMENT>
	OPTIONS
		-c Your custom config path
			ex. ~/.config/Funcher/doom.json
		-k Check Key Input focus others window to before get key number
		"; exit 1 ;;
	esac
done

if [ $RUN_KEY_LISTEN -eq 1 ]; then
	"$KEY_LISTEN"
fi

# Preparing Session
rm -f "$PIPE" "$LAST_KEY" "$LOCKFILE" "$EXIT_STATE"
mkfifo "$PIPE"
touch "$LAST_KEY"

# Input listening
if [ ! -f "$KEY_LISTEN" ]; then
    echo "Error: Listener executable not found at $KEY_LISTEN"
    echo "Please compile it first using 'make keyboard_listener'."
    exit 1
fi

nohup "$KEY_LISTEN" > /dev/null 2>&1 &

# Global Vars
WM=$(jq -r '.CURRENT_WM' "$CONFIG")
VIDEO_PATH=$(jq -r '.VIDEO_PATH' "$CONFIG")
VIDEO_NAME=$(basename $VIDEO_PATH)
VIDEO_FPS=$(jq -r '.VIDEO_FPS' "$CONFIG")
APP_CLASS=$(jq -r '.LAUNCHER["APP_CLASS"]' "$CONFIG")
LAUNCHER=$(jq -r '.LAUNCHER["APP_ID"]' "$CONFIG")
LAUNCHER_ARG=$(jq -r '.LAUNCHER["RUN_ARG"]' "$CONFIG")
DELAY_LAUNCHER_TIMER=$(jq -r '.LAUNCHER["DELAY_START"]' "$CONFIG")

CUSTOM_WS=$(jq -r '.OTHERS["CUSTOM_WORKSPACE"]' "$CONFIG")

declare -A ALL_INPUT

MOVE_TO_CURRENT="move_to_current"
SCRATCHPAD_SHOW="scratchpad_show"
MOVE_TO_SCRATCHPAD="move_to_scratchpad"

main () {
	# Main vars with custom function
	START=$(convert_time_to_decimal "$(jq -r '.VIDEO_CTRL["START"]' "$CONFIG")" "$VIDEO_FPS")
	IDLE_START=$(convert_time_to_decimal "$(jq -r '.VIDEO_CTRL["IDLE_LOOP"][0]' "$CONFIG")" "$VIDEO_FPS")
	IDLE_END=$(convert_time_to_decimal "$(jq -r '.VIDEO_CTRL["IDLE_LOOP"][1]' "$CONFIG")" "$VIDEO_FPS")
	EXIT_START=$(convert_time_to_decimal "$(jq -r '.VIDEO_CTRL["EXIT"][0]' "$CONFIG")" "$VIDEO_FPS")
	EXIT_END=$(convert_time_to_decimal "$(jq -r '.VIDEO_CTRL["EXIT"][1]' "$CONFIG")" "$VIDEO_FPS")
	END_COOLDOWN=$(echo "$EXIT_END - $EXIT_START" | bc )

	# Start main function
	mpv_socket

	# Preload json
	preload_input

	touch "$LOCKFILE"
	
	mpv_play_segment $START

	wait_for_window "mpv"
	window_marker "mpv" "mympv"

	# Move to focus workspace
	window_ctrl "mympv" "$MOVE_TO_CURRENT"

	# Start input control
	exec 3<>"$PIPE"
	read_input
	play_input_anim
	
	# Start idle loop
	mpv_play_loop $IDLE_START $IDLE_END
	
	# Start main APP
	sleep $DELAY_LAUNCHER_TIMER
	launcher_selected "$LAUNCHER" "$LAUNCHER_ARG"

	# Play exit animation also wait for last anim finished
	while true; do
		if [ ! -f "$LOCKFILE" ] && [ -f "$EXIT_STATE" ]; then
			touch "$LOCKFILE"
			mpv_play_segment $EXIT_START
			sleep $END_COOLDOWN
			rm -f "$LOCKFILE"
			break
		fi
		sleep 0.05
	done

	# Quit mpv
	window_ctrl "mympv" "$MOVE_TO_SCRATCHPAD"
	mpv_cmd '{ "command": ["set_property", "pause", true] }'

}


convert_time_to_decimal() {
    	local timecode=$1
    	local fps=$2
    	local minutes=0
    	local seconds=0
    	local frames=0

    	if [[ "$timecode" =~ ([0-9]+):([0-9]+)\;([0-9]+) ]]; then
        	minutes=${BASH_REMATCH[1]}
        	seconds=${BASH_REMATCH[2]}
        	frames=${BASH_REMATCH[3]}
        	echo "($minutes * 60) + $seconds + ($frames / $fps)" | bc -l

    	elif [[ "$timecode" =~ ([0-9]+)\;([0-9]+) ]]; then
        	seconds=${BASH_REMATCH[1]}
        	frames=${BASH_REMATCH[2]}
        	echo "$seconds + ($frames / $fps)" | bc -l

    	else
        	echo "$timecode"
    	fi
}

preload_input () {
    	while IFS="=" read -r key values; do
		
		if [ -z "$key" ]; then
            		continue
        	fi

        	local start_time=$(echo "$values" | awk '{print $1}')
        	local end_time=$(echo "$values" | awk '{print $2}')
        	local flag=$(echo "$values" | awk '{print $3}')

        	local start_decimal=$(convert_time_to_decimal "$start_time" "$VIDEO_FPS")
        	local end_decimal=$(convert_time_to_decimal "$end_time" "$VIDEO_FPS")
        	local duration=$(echo "$end_decimal - $start_decimal" | bc -l)

        	# Store the final
		ALL_INPUT["$key"]="$start_decimal $end_decimal $duration $flag"

    	done < <(
        	jq -r '.INPUT | to_entries[] | "\(.key)=\(.value[0]) \(.value[1]) \(.value[2])"' "$CONFIG"
    	)
}

read_input () {
	while read -r line <&3; do
		if [ ! -f "$LOCKFILE" ]; then
        		echo "$line" > "$LAST_KEY"
		fi
	done &
	READER_PID=$!
}

play_input_anim () {
	while true; do
		if [ ! -f "$LOCKFILE" ] && [ -s "$LAST_KEY" ]; then
			token=$(<"$LAST_KEY")
			: > "$LAST_KEY"
			
			# To prevent mpv steal app focus
			case $token in
				"left" | "right" | "middle" ) window_focus "myapp" ;;
			esac

			if [[ -z "${ALL_INPUT[$token]:-}" ]]; then
               			continue
            		fi

			touch "$LOCKFILE"
			input_timestamp=(${ALL_INPUT[$token]:-})
			anim_control ${input_timestamp[0]} ${input_timestamp[2]} ${input_timestamp[3]} 
			rm -f "$LOCKFILE"
		fi
		sleep 0.05
	done &
	INPUT_PID=$!
}

anim_control () {
	local start_segment=$1
	local cooldown=$2
	local display_app=$3
	
	case $display_app in
		"hide>start") 
			window_ctrl "myapp" "$MOVE_TO_SCRATCHPAD"
			mpv_play_segment $start_segment
			sleep $cooldown
			mpv_play_segment $START
			sleep $DELAY_LAUNCHER_TIMER
			window_ctrl "myapp" "$SCRATCHPAD_SHOW"
			;;
		"hide>idle")
			window_ctrl "myapp" "$MOVE_TO_SCRATCHPAD"
			mpv_play_segment $start_segment
			sleep $cooldown
			mpv_play_segment $IDLE_START
			window_ctrl "myapp" "$SCRATCHPAD_SHOW"
			;;
		*)
			mpv_play_segment $start_segment
			sleep $cooldown
			mpv_play_segment $IDLE_START
			;;
	esac
}


window_marker () {
	local window=$1
	local mark_name=$2

	case $WM in
		i3) i3-msg "[class=\"$APP_CLASS\"] mark $mark_name" ;;
		sway) swaymsg "[app_id=\"$window\"] mark $mark_name" ;;
		hyprland)
			addr=$(hyprctl client -j | jq -r ".[] | select(.class == \"$window\") | .addresss" | head -n1)
			if [ -n "$addr" ]; then
				echo "$addr" > "/tmp/${mark_name}.addr"
			fi ;;
		*) echo "currently not support in $WM" on function window_marker ;;
	esac
}

window_ctrl() {
	local mark_name=$1
   	local action=$2

	case $WM in
        i3)
            case $action in
                move_to_current) i3-msg "[con_mark=\"$mark_name\"] move to workspace current" ;;
                scratchpad_show) i3-msg "[con_mark=\"$mark_name\"] scratchpad show" ;;
                move_to_scratchpad) i3-msg "[con_mark=\"$mark_name\"] move scratchpad" ;;
            esac
            ;;
        sway)
            case $action in
                move_to_current) swaymsg "[con_mark=\"$mark_name\"] move to workspace current" ;;
                scratchpad_show) swaymsg "[con_mark=\"$mark_name\"] scratchpad show" ;;
                move_to_scratchpad) swaymsg "[con_mark=\"$mark_name\"] move scratchpad" ;;
            esac
            ;;
        hyprland)
            addr=$(cat "/tmp/${mark_name}.addr" 2>/dev/null)
            if [ -n "$addr" ]; then
                case $action in
                    move_to_current) hyprctl dispatch focuswindow address:$addr ;;
                    scratchpad_show) hyprctl dispatch focuswindow address:$addr ;;
                    move_to_scratchpad) hyprctl dispatch movetoworkspace $CUSTOM_WS,address:$addr ;;
                esac
            fi
            ;;
        *)
            echo "Currently not support in $WM, on function window_ctrl"
            ;;
    esac
}

wait_for_window () {
	local app_class=$1
	local timeout=10
    	local start=$(date +%s)

    	case $WM in
        	i3) cmd="i3-msg -t get_tree" 
		    app_class=$APP_CLASS ;;
	    	sway) cmd="swaymsg -t get_tree" ;;
        	hyprland) cmd="hyprctl clients -j" ;;
        	*) echo "EXIT_STATE on: $WM not supported"; return 1 ;;
    	esac
	
    	while true; do
		if $cmd | jq -e --arg c "$app_class" '
        	.. | objects
        	| select(
            	(.window_properties.class? == $c)
            	or (.app_id? == $c)
            	or (.class? == $c)
            	or (.initialClass? == $c)
            	or ((.name // "") | test($c;"i"))
            	or ((.title // "") | test($c;"i"))
        	)' >/dev/null 2>&1; then
			echo "Window: $app_class detected"
			return 0
		fi
	
		# timeout check
        	local now=$(date +%s)
		if [ $((now - start)) -ge $timeout ]; then
			touch "$EXIT_STATE"
            		echo "Timeout waiting for window: $app_class Please make sure APP_ID is correct"
            		return 1
        	fi
            sleep 0.05
    	done
}

wait_for_window_closed() {
    	local app_class=$1

    	case $WM in
        	i3) cmd="i3-msg -t get_tree" 
		    app_class=$APP_CLASS ;;
        	sway) cmd="swaymsg -t get_tree" ;;
        	hyprland) cmd="hyprctl clients -j" ;;
        	*) echo "EXIT_STATE on: $WM not supported"; return 1 ;;
    	esac

    	while $cmd | jq -e --arg c "$app_class" '
        	.. | objects
        	| select(
            	(.window_properties.class? == $c)
            	or (.app_id? == $c)
            	or (.class? == $c)
            	or (.initialClass? == $c)
            	or ((.name // "") | test($c;"i"))
            	or ((.title // "") | test($c;"i"))
        	)' >/dev/null 2>&1; do
        	sleep 0.2
		if [ -f "$EXIT_STATE" ]; then
            		echo "Timeout: window for $app_class not found"
            	break
        	fi
    	done
}

window_focus () {
	local mark_name=$1
	case $WM in
		sway) swaymsg "[con_mark=\"$mark_name\"] focus" ;;
		i3) i3-msg "[con_mark=\"$mark_name\"] focus" ;;
		hyprland) hyprctl dispatch focuswindow address:$(cat "/tmp/${mark_name}.addr") ;;
		*) echo "Currently not support $WM";;
	esac
}

mpv_socket () {
	# Preparing socket
	if [ -S "$SOCK" ] && echo '{ "command": ["get_version"] }' | socat - "$SOCK" >/dev/null 2>&1; then
		echo "mpv socat running: $SOCK"
	else
		echo "Start new mpv..."
		eval "$MPV_STARTUP"
	fi
	
	# init and replace vdo
	mpv_cmd "{ \"command\": [\"loadfile\", \"$VIDEO_PATH\", \"replace\"] }"
}

mpv_play_segment () {
	local play_segment=$1
	mpv_cmd "{ \"command\": [\"set_property\", \"time-pos\", $play_segment] }"
	mpv_cmd "{ \"command\": [\"set_property\", \"pause\", false] }"
}

mpv_play_loop () {
	local loop_start=$1
	local loop_end=$2
	mpv_cmd "{ \"command\": [\"set_property\", \"ab-loop-a\", $loop_start] }"
	mpv_cmd "{ \"command\": [\"set_property\", \"ab-loop-b\", $loop_end] }"
	mpv_cmd '{ "command": ["set_property", "loop-playlist", "inf"] }'
}

mpv_stop_loop () {
    	mpv_cmd '{ "command": ["set_property", "ab-loop-a", null] }'
    	mpv_cmd '{ "command": ["set_property", "ab-loop-b", null] }'
}

mpv_cmd () {
	socat - "$SOCK" <<< "$1"
}

launcher_selected () {
    	local app_launched=$1   
    	local launcher_cmd=$2

    	# Start launcher
    	sh -c "$launcher_cmd" & 

	wait_for_window "$app_launched"
    	
	window_marker "$app_launched" "myapp"
	window_focus "myapp"
	
	rm -f "$LOCKFILE"
	# window_ctrl "myapp" "$SCRATCHPAD_SHOW" # Dev test with rofi, You may need to move to scratchpad in WM .config 
	# then after app start just show it, But don't needed for most app, So just noted that
	
	# Try to use only main launcher to block process, But for some wofi (run) app make mpv stay open even wofi close, So put while loop for check window for now..
	wait_for_window_closed $app_launched
	touch "$EXIT_STATE"
}


cleanup () {
	pkill -f $KEY_LISTEN
	rm -f "$PIPE" "$LAST_KEY" "$LOCKFILE" "$EXIT_STATE" /tmp/*.addr /tmp/input_key.txt
	kill "$READER_PID" "$INPUT_PID" 2>/dev/null || true
}

trap cleanup EXIT INT TERM

main "$@"
