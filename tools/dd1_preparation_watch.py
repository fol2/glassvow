"""Bounded kernel mutation audit for generated slots; never relaxes isolation.

Original inputs are protected by read-only mounts, not by this observer. This
observer rejects undeclared transient output even if later deleted. Queue/read
limits fail closed. No helper/engine is invoked and no guest pointer is read.
"""
import ctypes
import errno
import os
from pathlib import Path, PurePosixPath
import struct
import dd1_reservations as r

# inotify ABI: MODIFY, ATTRIB, CLOSE_WRITE, MOVED_FROM/TO, CREATE, DELETE,
# DELETE_SELF, MOVE_SELF. The fd never reaches the workload.
MASK = 0x00000fce
FATAL = 0x00002c00 | 0x00004000 | 0x00008000  # self-move/delete, unmount, overflow, ignored
MAX_EVENTS, MAX_BYTES = 4096, 131072


class Watch:
    def __init__(self, capture, recipe):
        self.fd = -1
        self.paths = {}
        self.allowed = set()
        if recipe is None:
            return
        base = capture / 'generated'
        for index, slot in enumerate(recipe['slots']):
            prefix = str(index)
            self.allowed.add(prefix)
            for name in (*slot['files'], *slot.get('temporary_files', [])):
                if not name:
                    continue
                full = prefix + '/' + name
                self.allowed.add(full)
                self.allowed.update(str(p) for p in PurePosixPath(full).parents if str(p) != '.')
        libc = ctypes.CDLL(None, use_errno=True)
        fd = libc.inotify_init1(os.O_NONBLOCK | os.O_CLOEXEC)
        r.need(fd >= 0, 'generated output observer unavailable')
        self.fd = fd
        try:
            paths = [base, *sorted(base.rglob('*'))]
            r.need(len(paths) <= 4096, 'generated watch count')
            for p in paths:
                r.need(not p.is_symlink(), 'generated observer alias')
                # Watch files too: replacement of a file-slot backing must not
                # detach validation from the inode actually mounted in /source.
                wd = libc.inotify_add_watch(fd, os.fsencode(p), MASK)
                r.need(wd >= 0, 'generated watch installation failed')
                self.paths[wd] = p.relative_to(base).as_posix()
        except BaseException:
            self.close()
            raise

    def close(self):
        if self.fd >= 0:
            os.close(self.fd)
            self.fd = -1

    def finish(self):
        if self.fd < 0:
            return dict(ok=True, events=0, scope='no preparation')
        errors, count, total = [], 0, 0
        try:
            while True:
                try:
                    block = os.read(self.fd, 65536)
                except BlockingIOError:
                    break
                if not block:
                    break
                total += len(block)
                if total > MAX_BYTES:
                    errors.append('generated observer byte limit'); break
                at = 0
                while at < len(block):
                    r.need(at + 16 <= len(block), 'truncated inotify event')
                    wd, mask, cookie, size = struct.unpack_from('iIII', block, at)
                    r.need(at + 16 + size <= len(block), 'truncated inotify name')
                    name = os.fsdecode(block[at+16:at+16+size].split(b'\0', 1)[0])
                    prefix = self.paths.get(wd)
                    full = name if prefix == '.' else str(prefix) + ('/' + name if name else '')
                    count += 1
                    if mask & FATAL or prefix is None:
                        errors.append('generated observer lost/replaced inode or overflow')
                    elif full not in self.allowed:
                        errors.append('undeclared generated mutation:' + full)
                    if len(errors) > 16 or count > MAX_EVENTS:
                        errors = errors[:16] + ['generated observer event limit']; break
                    at += 16 + size
                if len(errors) > 16 or count > MAX_EVENTS:
                    break
            return dict(ok=not errors, events=count, bytes_read=total, errors=errors,
                        scope='kernel generated-path mutation audit; not import-semantic validation')
        finally:
            self.close()
