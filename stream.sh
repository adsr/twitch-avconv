#!/bin/bash
twitch_key_file="${HOME}/.twitch_key"
output_w=800
output_h=600
output_aspect=$(echo "scale=2; ${output_w}/${output_h}" | bc)
output_size="${output_w}x${output_h}"
side_w=240
wcam_dev=/dev/video0
game_dev=/dev/video1
game_w=$(echo "${output_w}-${side_w}"| bc)
num_threads=$(lscpu | grep '^CPU(s):' | awk '{print $2}')

# Get twitch_key
if [ ! -f "${twitch_key_file}" ]; then
    echo "Paste your stream key in ${twitch_key_file} first. Get it here:"
    echo "    http://www.twitch.tv/inkject/dashboard/streamkey"
    exit 1
fi
twitch_key=$(cat "${twitch_key_file}" | tr -d '\n')

# Get timer window
echo "Click on the timer window you'd like to stream..."
echo
wndw_info=$(xwininfo -stats)
wndw_pos=$(echo "${wndw_info}" | awk 'FNR==8 { printf("%d,", $NF); getline; print $NF }')
wndw_w=$(echo "${wndw_info}" | awk 'FNR==12 { print $NF }')
wndw_h=$(echo "${wndw_info}" | awk 'FNR==13 { print $NF }')

# Get game source
game_source=("-f" "video4linux2" "-i" "${game_dev}")
gscale="${game_w}:-1"
if [ -n "$1" ]; then
    echo "Click on the game window you'd like to stream..."
    echo
    gwndw_info=$(xwininfo -stats)
    gwndw_pos=$(echo "${gwndw_info}" | awk 'FNR==8 { printf("%d,", $NF); getline; print $NF }')
    gwndw_w=$(echo "${gwndw_info}" | awk 'FNR==12 { print $NF }')
    gwndw_h=$(echo "${gwndw_info}" | awk 'FNR==13 { print $NF }')
    gwndw_aspect=$(echo "scale=2; ${gwndw_w}/${gwndw_h}" | bc)
    if [ $(echo "${gwndw_aspect}<${output_aspect}" | bc) -ge 1 ]; then
        gscale="-1:${game_h}"
    fi
    game_source=("-f" "x11grab" "-framerate" "30" "-s" "${gwndw_w}x${gwndw_h}" "-i" ":0.0+${gwndw_pos}")
fi

# Stream
avconv \
    -f alsa -i hw:0,0 \
    "${game_source[@]}" \
    -f video4linux2 -i "${wcam_dev}" \
    -f x11grab -framerate 30 -s "${wndw_w}x${wndw_h}" -i ":0.0+${wndw_pos}" \
    -threads "${num_threads}" \
    -s "${output_size}" \
    -filter_complex "[1:v]format=yuv420p,scale=${gscale}[game];
                     [2:v]format=monow,scale=${side_w}:-1,unsharp[wcam];
                     [3:v]format=yuv420p,scale=${side_w}:-1,pad=${output_w}:${output_h}:${game_w}:0:black[wndw];
                     [wndw][game]overlay=0:0[game_wndw];
                     [game_wndw][wcam]overlay=${game_w}:H-h" \
    -f flv -ac 2 -ar 44100 -vcodec libx264 \
    -g 60 -keyint_min 30 -b:v 1000k -minrate 1000k -maxrate 1000k \
    -pix_fmt yuv420p -preset ultrafast -tune film \
    -strict normal -bufsize 1000k \
    "rtmp://live-jfk.twitch.tv/app/${twitch_key}"

# To test, replace last line with:
#     -c:v rawvideo -f nut - | avplay -i -
