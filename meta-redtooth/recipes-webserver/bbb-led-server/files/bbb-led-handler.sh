#!/bin/sh
# HTTP request handler executed once per connection by bbb-led-server.sh.
# Reads one HTTP request from stdin, writes one HTTP response to stdout.

LED_DEV="/dev/bbb_led"
HTML="/var/www/index.html"

# Read the request line: e.g. "GET /?action=on HTTP/1.1"
read -r req_line

# Extract the path+query-string field (second word)
path_qs="${req_line#* }"
path_qs="${path_qs%% *}"

# Drain remaining headers so nc can send the response cleanly
while read -r header; do
    header="${header%$'\r'}"
    [ -z "$header" ] && break
done

# Split query string from path
qs="${path_qs#*\?}"
[ "$qs" = "$path_qs" ] && qs=""   # no '?' in URL

# Helpers
ok_text() { printf 'HTTP/1.0 200 OK\r\nContent-Type: text/plain\r\nConnection: close\r\n\r\n%s\n' "$1"; }
ok_html() { printf 'HTTP/1.0 200 OK\r\nContent-Type: text/html\r\nConnection: close\r\n\r\n'; cat "$HTML"; }

case "$qs" in
    *action=on*)
        printf '1' > "$LED_DEV" 2>/dev/null
        ok_text "LED ON"
        ;;
    *action=off*)
        printf '0' > "$LED_DEV" 2>/dev/null
        ok_text "LED OFF"
        ;;
    *action=status*)
        v=$(cat "$LED_DEV" 2>/dev/null)
        [ "$v" = "1" ] && ok_text "LED ON" || ok_text "LED OFF"
        ;;
    *)
        # Serve the control page for / , /index.html, favicon, etc.
        ok_html
        ;;
esac
