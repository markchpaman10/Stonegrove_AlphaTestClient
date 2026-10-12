"""GitHub is the sole server world source. Downloads remain immutable in memory."""
import hashlib
from dataclasses import dataclass
from datetime import datetime, timezone
import base64
import json
import os
import re
import urllib.error
import urllib.parse
import urllib.request
import zlib
from pathlib import Path

MAX_PACKAGE = 16000000

def parse_link(value):
    value = value.strip()
    match = re.fullmatch(r'worldLink\s*=\s*(.+?)\s*;?', value)
    if match:
        value = match.group(1).rstrip(';').strip()
    return value.strip('"\'').strip()

def github_url(value):
    value = parse_link(value)
    u = urllib.parse.urlsplit(value)
    if u.scheme != 'https' or u.username or u.password or u.port not in (None, 443):
        raise ValueError('World link must be an HTTPS GitHub file link')
    host = (u.hostname or '').lower()
    if host not in {'github.com', 'raw.githubusercontent.com'}:
        raise ValueError('World link must use github.com or raw.githubusercontent.com')
    if host == 'github.com':
        parts = u.path.split('/')
        repo = re.fullmatch(r'/([\w.-]+)/([\w.-]+)/?', u.path)
        if repo:
            return 'https://github.com/' + repo.group(1) + '/' + repo.group(2).removesuffix('.git')
        if len(parts) >= 6 and parts[3] in {'blob', 'raw'}:
            return 'https://raw.githubusercontent.com/' + '/'.join(parts[1:3] + parts[4:])
        if len(parts) < 7 or not (parts[3:5] == ['releases', 'download'] or parts[3:6] == ['releases', 'latest', 'download']):
            raise ValueError('Paste a GitHub file, raw file or release download link, not a repository page')
    elif len(u.path.split('/')) < 5:
        raise ValueError('Paste the full raw GitHub world file link')
    return urllib.parse.urlunsplit((u.scheme, u.netloc, u.path, u.query, ''))

def decode_world(raw):
    if len(raw) > MAX_PACKAGE or not raw.startswith(b'STONEGROVE_WORLD_1\n'):
        raise ValueError('Invalid world package: expected a .sgworld file')
    decoder = zlib.decompressobj()
    try:
        plain = decoder.decompress(raw[19:], 64000001)
        if len(plain) > 64000000 or not decoder.eof or decoder.unused_data:
            raise ValueError('World package too large, incomplete or has trailing data')
        document = json.loads(plain)
        if not isinstance(document, dict) or document.get('format') != 'StonegroveWorldPackage' or document.get('version') != 1:
            raise ValueError('Unsupported world package')
        required = {'current', 'item_data', 'npc_data', 'monster_data', 'quest_data', 'event_data'}
        if not isinstance(document.get('files'), dict) or not required.issubset(document['files']):
            raise ValueError('GitHub world package is missing required world definitions')
        imported = {}
        for path, encoded in document.get('assets', {}).items():
            png = base64.b64decode(encoded, validate=True)
            if not path.startswith('assets/imported/') or '..' in path or not png.startswith(b'\x89PNG\r\n\x1a\n') or len(png) < 24:
                raise ValueError('Invalid imported world artwork')
            imported[path] = [int.from_bytes(png[16:20], 'big'), int.from_bytes(png[20:24], 'big')]
        document['importedDimensions'] = imported
        return document
    except (zlib.error, json.JSONDecodeError, UnicodeError, TypeError, AttributeError, base64.binascii.Error) as exc:
        raise ValueError('Invalid world package contents') from exc

class GithubRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        u = urllib.parse.urlsplit(newurl)
        host = (u.hostname or '').lower()
        if u.scheme != 'https' or u.username or u.password or u.port not in (None, 443) or not (host in {'github.com', 'api.github.com'} or host.endswith('.githubusercontent.com')):
            raise ValueError('World download redirected outside GitHub')
        return super().redirect_request(req, fp, code, msg, headers, newurl)

def download_world(link, opener=None):
    url = github_url(link)
    opener = opener or urllib.request.build_opener(GithubRedirect())
    repo = re.fullmatch(r'https://github.com/([\w.-]+)/([\w.-]+)', url)
    if repo:
        api = 'https://api.github.com/repos/' + repo.group(1) + '/' + repo.group(2)
        request = urllib.request.Request(api, headers={'User-Agent': 'Stonegrove-WorldLoader/1', 'Accept': 'application/vnd.github+json'})
        try:
            with opener.open(request, timeout=30) as response:
                metadata = response.read(1000001)
            if len(metadata) > 1000000:
                raise ValueError('GitHub repository metadata is too large')
            branch = json.loads(metadata).get('default_branch')
            if not isinstance(branch, str) or not branch:
                raise ValueError('GitHub repository has no default branch')
            url = 'https://raw.githubusercontent.com/' + repo.group(1) + '/' + repo.group(2) + '/' + urllib.parse.quote(branch, safe='') + '/world.sgworld'
        except (urllib.error.URLError, OSError, ValueError, AttributeError) as exc:
            raise ValueError(f'Could not resolve public GitHub repository: {exc}') from exc
    request = urllib.request.Request(url, headers={'User-Agent': 'Stonegrove-WorldLoader/1', 'Accept': 'application/octet-stream'})
    try:
        with opener.open(request, timeout=30) as response:
            size = response.headers.get('Content-Length')
            if size and int(size) > MAX_PACKAGE:
                raise ValueError('World download exceeds 16 MB')
            raw = response.read(MAX_PACKAGE + 1)
    except (urllib.error.URLError, OSError) as exc:
        raise ValueError(f'Could not download GitHub world: {exc}') from exc
    return GitHubWorld(bytes(raw), github_url(link), url)


@dataclass(frozen=True)
class GitHubWorld:
    raw: bytes
    configured_url: str
    resolved_url: str

    def __post_init__(self):
        if not isinstance(self.raw, bytes):
            raise ValueError('Server world must be an immutable GitHub download')
        github_url(self.configured_url)
        github_url(self.resolved_url)
        decode_world(self.raw)

    @property
    def sha256(self):
        return hashlib.sha256(self.raw).hexdigest()

    @property
    def world_id(self):
        current = decode_world(self.raw)['files']['current']
        return next((e['value'] for e in current.get('entries', []) if e.get('key') == 'worldId'), '(unknown)')


def resolve_world(root, data_dir, world=None, link=None, interactive=False, read=input, log=print, downloader=download_world):
    # root and legacy local world/cache files are deliberately never consulted.
    data_dir = Path(data_dir)
    config = data_dir / 'world-link.json'
    if world:
        alias = parse_link(str(world))
        github_url(alias)  # Local --world paths are rejected, even if they exist.
        if link and github_url(link) != github_url(alias):
            raise ValueError('Configure one GitHub world link; --world and --world-link disagree')
        link = alias
    if not link and config.is_file():
        try:
            link = json.loads(config.read_text(encoding='utf-8')).get('worldLink')
        except (ValueError, AttributeError) as exc:
            raise ValueError(f'Invalid saved GitHub world link configuration: {config}') from exc
    if not link and interactive:
        log('GitHub world link required. Paste worldLink = "https://github.com/.../world.sgworld".', flush=True)
        try:
            link = parse_link(read('GitHub world link: '))
        except EOFError:
            link = None
    if not link:
        raise ValueError('GitHub world link required. Set WORLD_LINK, use --world-link, or enter the link in the console. Local files, cached packages and bundled worlds are disabled.')
    url = github_url(link)
    log(f'WORLD SOURCE: GitHub only: {url}', flush=True)
    log('Downloading a fresh world package. Local and cached worlds are disabled.', flush=True)
    result = downloader(url)
    if not isinstance(result, GitHubWorld) or result.configured_url != url:
        raise ValueError('World loader did not return the configured GitHub download')
    decode_world(result.raw)
    data_dir.mkdir(parents=True, exist_ok=True)
    temp = config.with_suffix('.tmp')
    try:
        temp.write_text(json.dumps({'worldLink': url}, indent=2) + '\n', encoding='utf-8')
        os.replace(temp, config)
    finally:
        temp.unlink(missing_ok=True)
    audit = data_dir / 'world-source.json'
    temp = audit.with_suffix('.tmp')
    try:
        temp.write_text(json.dumps({'source': 'github', 'configuredUrl': url, 'downloadUrl': result.resolved_url, 'sha256': result.sha256, 'worldId': result.world_id, 'downloadedAt': datetime.now(timezone.utc).isoformat()}, indent=2) + '\n', encoding='utf-8')
        os.replace(temp, audit)
    finally:
        temp.unlink(missing_ok=True)
    log(f'WORLD DOWNLOAD: {result.resolved_url}', flush=True)
    log(f'WORLD ID: {result.world_id}', flush=True)
    log(f'WORLD SHA256: {result.sha256}', flush=True)
    log(f'Remembered GitHub world link: {config}', flush=True)
    return result
