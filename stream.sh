#!/bin/bash
twitch_key_file="${HOME}/.twitch_key"
output_w=1280
output_h=720
output_size="${output_w}x${output_h}"
side_w=360
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

# Get window
echo "Click on the window you'd like to stream..."
echo
wndw_info=$(xwininfo -stats)
wndw_pos=$(echo "${wndw_info}" | awk 'FNR==8 { printf("%d,", $NF); getline; print $NF }')
wndw_w=$(echo "${wndw_info}" | awk 'FNR==12 { print $NF }')
wndw_h=$(echo "${wndw_info}" | awk 'FNR==13 { print $NF }')

# Stream
avconv \
    -f alsa -i hw:0,0 \
    -f video4linux2 -i "${game_dev}" \
    -f video4linux2 -i "${wcam_dev}" \
    -f x11grab -framerate 30 -s "${wndw_w}x${wndw_h}" -i ":0.0+${wndw_pos}" \
    -threads "${num_threads}" \
    -s "${output_size}" \
    -filter_complex "[1:v]scale=${game_w}:-1,pad=${output_w}:${output_h}:0:0:black[game];
                     [2:v]scale=${side_w}:-1[wcam];
                     [3:v]crop=${wndw_w}:${wndw_h}[wndw];
                     [game][wndw]overlay=${game_w}:0[game_wndw];
                     [game_wndw][wcam]overlay=${game_w}:H-h" \
    -f flv -ac 2 -ar 44100 -vcodec libx264 \
    -g 60 -keyint_min 30 -b:v 1000k -minrate 1000k -maxrate 1000k \
    -pix_fmt yuv420p -preset ultrafast -tune film \
    -strict normal -bufsize 1000k \
    "rtmp://live-jfk.twitch.tv/app/${twitch_key}"

# To test, replace last line with:
#     -c:v rawvideo -f nut - | avplay -i -
