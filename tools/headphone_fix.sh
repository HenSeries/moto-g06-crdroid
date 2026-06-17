#!/system/bin/sh
# Headphone Jack Fix for MT6768 GSI
# Monitors accdet input events and forces tinymix routing
#
# Controls:
#   154 = Headphone Plugged In (Off/On)
#   189 = DAC In Mux (Normal Path)
#   191 = HPL Mux (Open/LoudSPK Playback/Audio Playback/...)
#   192 = HPR Mux (Open/LoudSPK Playback/Audio Playback/...)

JACK_DEV="/dev/input/event3"
LOG_TAG="HeadphoneFixd"

log() {
    log -t "$LOG_TAG" "$1" 2>/dev/null || echo "$LOG_TAG: $1"
}

set_headphone_on() {
    log "Headphone plugged in - routing audio"
    # Set multiple times with delays to fight HAL resets
    for i in 1 2 3; do
        tinymix 154 1   # Headphone Plugged In: On
        tinymix 189 0   # DAC In Mux: Normal Path
        tinymix 191 2   # HPL Mux: Audio Playback
        tinymix 192 2   # HPR Mux: Audio Playback
        sleep 0.3
    done
}

set_headphone_off() {
    log "Headphone unplugged - routing to speaker"
    tinymix 154 0   # Headphone Plugged In: Off
    tinymix 191 0   # HPL Mux: Open
    tinymix 192 0   # HPR Mux: Open
}

# Check initial state from accdet
ACCDET_STATE=$(dmesg | grep -o 'accdet.*Plug[A-Za-z]*' | tail -1)
if echo "$ACCDET_STATE" | grep -q "PlugIn"; then
    log "Initial state: headphones plugged in"
    set_headphone_on
fi

log "Monitoring $JACK_DEV for jack events..."

# Monitor jack events
getevent -ql "$JACK_DEV" | while read timestamp type code value; do
    case "$code" in
        SW_HEADPHONE_INSERT|SW_MICROPHONE_INSERT|SW_JACK_PHYSICAL_INSERT)
            case "$value" in
                *DOWN*|*0001*)
                    set_headphone_on
                    # Keep reinforcing for 2 seconds to beat HAL resets
                    (sleep 1 && tinymix 154 1 && tinymix 191 2 && tinymix 192 2) &
                    (sleep 2 && tinymix 154 1 && tinymix 191 2 && tinymix 192 2) &
                    ;;
                *UP*|*0000*)
                    set_headphone_off
                    ;;
            esac
            ;;
    esac
done
