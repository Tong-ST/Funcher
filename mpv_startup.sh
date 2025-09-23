#!/usr/bin/env bash

mpv_control="--no-config --profile=fast --title=mpv_preload \
--hwdec=auto-copy \
--vo=gpu \
--cache=yes --demuxer-max-bytes=100M \
--demuxer-readahead-secs=3 \
--scale=bilinear \
--cscale=bilinear \
--dscale=bilinear \
--vd-lavc-skiploopfilter=all \
--deband=no \
--no-border \
--background=none \
--no-osc \
--no-input-default-bindings \
--input-conf=/dev/null \
--no-terminal \
--idle \
--pause \
--force-window=no \
--keep-open=always"

socket="/tmp/mpv_socket"

# cleanup old instances
pkill -f "mpv.*mpv_preload" 2>/dev/null
rm -f /tmp/mpv_socket*

# preload
setsid mpv --input-ipc-server="$socket" $mpv_control &
pid=$!

# wait for socket
for i in {1..50}; do
    [ -S "$socket" ] && break
    sleep 0.1
done

if [ ! -S "$socket" ]; then
    echo "Failed to start mpv preload."
    kill "$pid" 2>/dev/null
    exit 1
fi

echo "mpv preload started (pid $pid, socket $socket)"

