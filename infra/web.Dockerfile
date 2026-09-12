FROM caddy:2.10.2-alpine
COPY infra/Caddyfile /etc/caddy/Caddyfile
COPY apps/gomoku_app/build/web /srv/gomoku
