/*
 * bbb-led-server.c - Minimal HTTP server for BBB LED control
 * Listens on port 80, serves index.html and handles LED control via /dev/bbb_ledN
 *
 * URL scheme:
 *   GET /               → serve index.html
 *   GET /?led=N&action=on|off|status  → control USR LED N (0..3)
 *   led parameter defaults to 0 if omitted
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <signal.h>

#define PORT        80
#define NUM_LEDS    4
#define INDEX_HTML  "/var/www/index.html"
#define BUFSIZE     2048

static const char *LED_DEVS[NUM_LEDS] = {
    "/dev/bbb_led0",
    "/dev/bbb_led1",
    "/dev/bbb_led2",
    "/dev/bbb_led3",
};

static void send_text(int fd, const char *body)
{
    char hdr[256];
    int n = snprintf(hdr, sizeof(hdr),
        "HTTP/1.0 200 OK\r\n"
        "Content-Type: text/plain\r\n"
        "Connection: close\r\n"
        "\r\n");
    write(fd, hdr, n);
    write(fd, body, strlen(body));
}

static void send_html(int fd)
{
    const char *hdr =
        "HTTP/1.0 200 OK\r\n"
        "Content-Type: text/html\r\n"
        "Connection: close\r\n"
        "\r\n";
    int f = open(INDEX_HTML, O_RDONLY);
    if (f < 0) { send_text(fd, "index.html not found\n"); return; }
    write(fd, hdr, strlen(hdr));
    char buf[BUFSIZE];
    int n;
    while ((n = read(f, buf, sizeof(buf))) > 0)
        write(fd, buf, n);
    close(f);
}

static void led_set(int idx, int val)
{
    if (idx < 0 || idx >= NUM_LEDS) return;
    int f = open(LED_DEVS[idx], O_WRONLY);
    if (f >= 0) { write(f, val ? "1" : "0", 1); close(f); }
}

static int led_get(int idx)
{
    char c = '0';
    if (idx < 0 || idx >= NUM_LEDS) return 0;
    int f = open(LED_DEVS[idx], O_RDONLY);
    if (f >= 0) { read(f, &c, 1); close(f); }
    return c == '1';
}

static void handle_client(int cli)
{
    char buf[BUFSIZE];
    memset(buf, 0, sizeof(buf));
    read(cli, buf, sizeof(buf) - 1);

    /* Find query string in first request line: "GET /path?qs HTTP/1.x" */
    char *qs = strchr(buf, '?');
    if (qs) {
        qs++;
        char *sp = strchr(qs, ' ');
        if (sp) *sp = '\0';

        /* Parse led index (default 0) */
        int idx = 0;
        char *lp = strstr(qs, "led=");
        if (lp) {
            idx = atoi(lp + 4);
            if (idx < 0 || idx >= NUM_LEDS) idx = 0;
        }

        char resp[32];
        if (strstr(qs, "action=on")) {
            led_set(idx, 1);
            snprintf(resp, sizeof(resp), "LED ON\n");
            send_text(cli, resp);
        } else if (strstr(qs, "action=off")) {
            led_set(idx, 0);
            snprintf(resp, sizeof(resp), "LED OFF\n");
            send_text(cli, resp);
        } else if (strstr(qs, "action=status")) {
            snprintf(resp, sizeof(resp), "%s\n", led_get(idx) ? "LED ON" : "LED OFF");
            send_text(cli, resp);
        } else {
            send_html(cli);
        }
    } else {
        send_html(cli);
    }
    close(cli);
}

int main(void)
{
    signal(SIGCHLD, SIG_IGN);
    signal(SIGPIPE, SIG_IGN);

    int srv = socket(AF_INET, SOCK_STREAM, 0);
    int opt = 1;
    setsockopt(srv, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family      = AF_INET;
    addr.sin_port        = htons(PORT);
    addr.sin_addr.s_addr = INADDR_ANY;
    bind(srv, (struct sockaddr *)&addr, sizeof(addr));
    listen(srv, 5);

    for (;;) {
        int cli = accept(srv, NULL, NULL);
        if (cli < 0) continue;
        if (fork() == 0) {
            close(srv);
            handle_client(cli);
            exit(0);
        }
        close(cli);
    }
    return 0;
}
