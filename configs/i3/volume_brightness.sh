#!/bin/bash

# Volume_brightness.sh
# Last modified 2024-08-26

# Volume_brightness.sh by Nmoleo (https://gitlab.com/Nmoleo/i3-volume-brightness-indicator) 
# licensed under the GPLv3 (obtain the copy of the license at: https://www.gnu.org/licenses/gpl-3.0.txt)
# Here are the changes:
## > # See README.md for usage instructions
## > volume_step=1
## 14a8
## > download_album_art=true
## 30c24
## <     light | grep -Po '[0-9]{1,3}' | head -n 1
## ---
## >     sudo light | grep -Po '[0-9]{1,3}' | head -n 1
## 38c32
## <         volume_icon="󰝟 "
## ---
## >         volume_icon=""
## 40c34
## <         volume_icon=" "
## ---
## >         volume_icon=""
## 42c36
## <         volume_icon=" "
## ---
## >         volume_icon=""
## 53,54d46
## <     url=$(echo -e "${url//\%/\\x}")
## <     echo $url
## 57c49
## <     elif [[ $url == "http://"* ]]; then
## ---
## >     elif [[ $url == "http://"* ]] && [[ $download_album_art == "true" ]]; then
## 67c59
## <     elif [[ $url == "https://"* ]]; then
## ---
## >     elif [[ $url == "https://"* ]] && [[ $download_album_art == "true" ]]; then
## 147,159d138
## <     mic_mute)
## <     pactl set-source-mute @DEFAULT_SOURCE@ toggle
## <     volume=$(pactl get-source-volume @DEFAULT_SOURCE@ | grep -Po '[0-9]{1,3}(?=%)' | head -1)
## <     mute=$(pactl get-source-mute @DEFAULT_SOURCE@ | grep -Po '(?<=Mute: )(yes|no)')
## <     if [ "$volume" -eq 0 ] || [ "$mute" == "yes" ] ; then
## <         volume_icon="󰍭 "
## <     else
## <         volume_icon="󰍬 "
## <     fi
## <
## <     notify-send -t $notification_timeout -h string:x-dunst-stack-tag:volume_notif -h int:value:$volume "$volume_icon $volume%"
## <     ;;
## <
## 162c141
## <     light -A $brightness_step
## ---
## >     sudo light -A $brightness_step
## 168c147
## <     light -U $brightness_step
## ---
## >     sudo light -U $brightness_step
## (And the copyright notice)

volume_step=5
brightness_step=5
max_volume=100
notification_timeout=1000
show_album_art=true
show_music_in_volume_indicator=true

# Uses regex to get volume from pactl
function get_volume {
    pactl get-sink-volume @DEFAULT_SINK@ | grep -Po '[0-9]{1,3}(?=%)' | head -1
}

# Uses regex to get mute status from pactl
function get_mute {
    pactl get-sink-mute @DEFAULT_SINK@ | grep -Po '(?<=Mute: )(yes|no)'
}

# Uses regex to get brightness from xbacklight
function get_brightness {
    light | grep -Po '[0-9]{1,3}' | head -n 1
}

# Returns a mute icon, a volume-low icon, or a volume-high icon, depending on the volume
function get_volume_icon {
    volume=$(get_volume)
    mute=$(get_mute)
    if [ "$volume" -eq 0 ] || [ "$mute" == "yes" ] ; then
        volume_icon="󰝟 "
    elif [ "$volume" -lt 50 ]; then
        volume_icon=" "
    else
        volume_icon=" "
    fi
}

# Always returns the same icon - I couldn't get the brightness-low icon to work with fontawesome
function get_brightness_icon {
    brightness_icon=""
}

function get_album_art {
    url=$(playerctl -f "{{mpris:artUrl}}" metadata)
    url=$(echo -e "${url//\%/\\x}")
    echo $url
    if [[ $url == "file://"* ]]; then
        album_art="${url/file:\/\//}"
    elif [[ $url == "http://"* ]]; then
        # Identify filename from URL
        filename="$(echo $url | sed "s/.*\///")"

        # Download file to /tmp if it doesn't exist
        if [ ! -f "/tmp/$filename" ]; then
            wget -O "/tmp/$filename" "$url"
        fi

        album_art="/tmp/$filename"
    elif [[ $url == "https://"* ]]; then
        # Identify filename from URL
        filename="$(echo $url | sed "s/.*\///")"
        
        # Download file to /tmp if it doesn't exist
        if [ ! -f "/tmp/$filename" ]; then
            wget -O "/tmp/$filename" "$url"
        fi

        album_art="/tmp/$filename"
    else
        album_art=""
    fi
}

# Displays a volume notification
function show_volume_notif {
    volume=$(get_mute)
    get_volume_icon

    if [[ $show_music_in_volume_indicator == "true" ]]; then
        current_song=$(playerctl -f "{{title}} - {{artist}}" metadata)

        if [[ $show_album_art == "true" ]]; then
            get_album_art
        fi

        notify-send -t $notification_timeout -h string:x-dunst-stack-tag:volume_notif -h int:value:$volume -i "$album_art" "$volume_icon $volume%" "$current_song"
    else
        notify-send -t $notification_timeout -h string:x-dunst-stack-tag:volume_notif -h int:value:$volume "$volume_icon $volume%"
    fi
}

# Displays a music notification
function show_music_notif {
    song_title=$(playerctl -f "{{title}}" metadata)
    song_artist=$(playerctl -f "{{artist}}" metadata)
    song_album=$(playerctl -f "{{album}}" metadata)

    if [[ $show_album_art == "true" ]]; then
        get_album_art
    fi

    notify-send -t $notification_timeout -h string:x-dunst-stack-tag:music_notif -i "$album_art" "$song_title" "$song_artist - $song_album"
}

# Displays a brightness notification using dunstify
function show_brightness_notif {
    brightness=$(get_brightness)
    echo $brightness
    get_brightness_icon
    notify-send -t $notification_timeout -h string:x-dunst-stack-tag:brightness_notif -h int:value:$brightness "$brightness_icon $brightness%"
}

# Main function - Takes user input, "volume_up", "volume_down", "brightness_up", or "brightness_down"
case $1 in
    volume_up)
    # Unmutes and increases volume, then displays the notification
    pactl set-sink-mute @DEFAULT_SINK@ 0
    volume=$(get_volume)
    if [ $(( "$volume" + "$volume_step" )) -gt $max_volume ]; then
        pactl set-sink-volume @DEFAULT_SINK@ $max_volume%
    else
        pactl set-sink-volume @DEFAULT_SINK@ +$volume_step%
    fi
    show_volume_notif
    ;;

    volume_down)
    # Raises volume and displays the notification
    pactl set-sink-volume @DEFAULT_SINK@ -$volume_step%
    show_volume_notif
    ;;

    volume_mute)
    # Toggles mute and displays the notification
    pactl set-sink-mute @DEFAULT_SINK@ toggle
    show_volume_notif
    ;;

    mic_mute)
    pactl set-source-mute @DEFAULT_SOURCE@ toggle
    volume=$(pactl get-source-volume @DEFAULT_SOURCE@ | grep -Po '[0-9]{1,3}(?=%)' | head -1)
    mute=$(pactl get-source-mute @DEFAULT_SOURCE@ | grep -Po '(?<=Mute: )(yes|no)')
    if [ "$volume" -eq 0 ] || [ "$mute" == "yes" ] ; then
        volume_icon="󰍭 "
    else
        volume_icon="󰍬 "
    fi

    notify-send -t $notification_timeout -h string:x-dunst-stack-tag:volume_notif -h int:value:$volume "$volume_icon $volume%"
    ;;

    brightness_up)
    # Increases brightness and displays the notification
    light -A $brightness_step 
    show_brightness_notif
    ;;

    brightness_down)
    # Decreases brightness and displays the notification
    light -U $brightness_step
    show_brightness_notif
    ;;

    next_track)
    # Skips to the next song and displays the notification
    playerctl next
    sleep 0.5 && show_music_notif
    ;;

    prev_track)
    # Skips to the previous song and displays the notification
    playerctl previous
    sleep 0.5 && show_music_notif
    ;;

    play_pause)
    playerctl play-pause
    show_music_notif
    # Pauses/resumes playback and displays the notification
    ;;
esac
