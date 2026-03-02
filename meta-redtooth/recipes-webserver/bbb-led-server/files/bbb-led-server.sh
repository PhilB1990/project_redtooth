#!/bin/sh
# Minimal HTTP server for BBB LED control.
# Uses netcat + a named FIFO to achieve bidirectional I/O without httpd.
# Handles one request at a time (sufficient for single-user LED control).

FIFO=/tmp/bbb-led-fifo

cleanup() {
    rm -f "$FIFO"
}
trap cleanup EXIT INT TERM

while true; do
    rm -f "$FIFO"
    mkfifo "$FIFO"
    # handler reads the HTTP request from the FIFO (written by nc),
    # writes the HTTP response to its stdout (piped into nc's stdin).
    /usr/sbin/bbb-led-handler < "$FIFO" | busybox nc -l -p 80 > "$FIFO"
done
