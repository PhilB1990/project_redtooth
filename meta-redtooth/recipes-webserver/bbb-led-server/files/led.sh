#!/bin/sh

LED_DEV="/dev/bbb_led"

case "$QUERY_STRING" in
    *action=on*)
        echo "Content-Type: text/plain"
        echo "Access-Control-Allow-Origin: *"
        echo ""
        printf '1' > "$LED_DEV"
        echo "LED ON"
        ;;
    *action=off*)
        echo "Content-Type: text/plain"
        echo "Access-Control-Allow-Origin: *"
        echo ""
        printf '0' > "$LED_DEV"
        echo "LED OFF"
        ;;
    *action=status*)
        echo "Content-Type: text/plain"
        echo "Access-Control-Allow-Origin: *"
        echo ""
        VALUE=$(cat "$LED_DEV" 2>/dev/null)
        if [ "$VALUE" = "1" ]; then
            echo "LED ON"
        else
            echo "LED OFF"
        fi
        ;;
    *)
        # No action parameter: serve the main control page.
        # This is also used as the E404 handler so that http://<IP>/
        # works even if BusyBox httpd does not serve the directory index.
        echo "Content-Type: text/html"
        echo ""
        cat /var/www/index.html
        ;;
esac
