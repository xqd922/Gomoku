"""Reject release builds that silently point at a development server."""
import os
from urllib.parse import urlsplit


def validate():
    urls = {key: urlsplit(os.environ.get(key, '')) for key in
            ('GOMOKU_API_URL', 'GOMOKU_AUTH_URL', 'GOMOKU_WEB_URL')}
    for key, value in urls.items():
        if (value.scheme != 'https' or not value.hostname or value.username or
                value.password or value.query or value.fragment or
                value.hostname in {'localhost', '127.0.0.1', '::1'} or
                value.hostname.endswith(('.localhost', '.local'))):
            raise SystemExit(f'{key} must be a public HTTPS URL without credentials.')
    web = urls['GOMOKU_WEB_URL']
    if any((url.scheme, url.netloc) != (web.scheme, web.netloc) for url in urls.values()):
        raise SystemExit('Web, API and authentication must share an origin for HttpOnly cookies.')
    if urls['GOMOKU_API_URL'].path != '/api/' or urls['GOMOKU_AUTH_URL'].path != '/auth/':
        raise SystemExit('Release API/authentication paths must be /api/ and /auth/.')
    if web.path not in ('', '/'):
        raise SystemExit('The Web URL must use the origin root.')
    print('Production URLs validated:', web.hostname)


if __name__ == '__main__':
    validate()
