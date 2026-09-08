#!/usr/bin/env python3
"""
Disable /data metadata encryption on Moto G06 (lagos) by patching the
first-stage fstab inside vendor_boot.img.

Why: the Trustonic KeyMint TA cannot re-unwrap the metadata-encryption key
stored in /metadata on the SECOND boot, so /data never mounts and the device
hangs at the Motorola logo. Only the first boot after `fastboot erase metadata`
works. Removing `keydirectory=...` drops the metadata-encryption layer while
leaving /data itself FBE-encrypted via `fileencryption=`.

Method: the option is the LAST field on the fstab line, so it is overwritten
with an equal number of spaces. That keeps the decompressed cpio byte-length
identical -- no cpio re-archiving, no ownership/mode/selinux loss. Only the
LZ4-compressed size changes, which is fixed up in the header + ramdisk table.

Only ramdisk fragment 0 (the boot ramdisk) is touched. Fragment 1 (recovery)
is copied through byte-for-byte so recovery stays intact as a recovery path.
"""

import os
import struct
import subprocess
import sys
import tempfile

NEEDLE = b',keydirectory=/metadata/vold/metadata_encryption'

SRC = '/home/hen/Documentos/code/android/moto-g06-mod/tools/stock/vendor_boot.img'
DST = '/home/hen/Documentos/code/android/moto-g06-mod/images/vendor_boot-nometa.img'


def align(x, a):
    return ((x + a - 1) // a) * a


def lz4_d(src, dst):
    subprocess.run(['lz4', '-d', '-q', '-f', '--no-sparse', src, dst], check=True)


def lz4_c(src, dst):
    # -l = legacy frame format (magic 0x184C2102), matches the stock image
    subprocess.run(['lz4', '-l', '-9', '-q', '-f', src, dst], check=True)


def main():
    if not os.path.exists(SRC):
        sys.exit(f'missing source image: {SRC}')

    d = bytearray(open(SRC, 'rb').read())
    orig_total = len(d)

    magic, hv, ps, _ka, _ra, vrs = struct.unpack_from('<8sIIIII', d, 0)
    if magic != b'VNDRBOOT':
        sys.exit('not a vendor_boot image')
    if hv != 4:
        sys.exit(f'unsupported header version {hv} (expected 4)')

    hdr_size, dtb_size = struct.unpack_from('<II', d, 2096)
    vrt_size, vrt_num, vrt_entry_size, bootconfig_size = struct.unpack_from('<IIII', d, 2112)

    off_ramdisk = align(hdr_size, ps)
    off_dtb = off_ramdisk + align(vrs, ps)
    off_vrt = off_dtb + align(dtb_size, ps)
    off_bootcfg = off_vrt + align(vrt_size, ps)

    print(f'header v{hv}  page={ps}  vendor_ramdisk_size={vrs}')
    print(f'fragments={vrt_num}  dtb={dtb_size}  vrt={vrt_size}  bootconfig={bootconfig_size}')

    if vrt_num != 2:
        sys.exit(f'expected 2 ramdisk fragments, found {vrt_num} -- aborting, layout differs')

    entries = []
    for i in range(vrt_num):
        eo = off_vrt + i * vrt_entry_size
        rsz, roff, rtype = struct.unpack_from('<III', d, eo)
        rname = d[eo + 12:eo + 44].split(b'\x00')[0].decode()
        entries.append({'off_in_file': eo, 'size': rsz, 'offset': roff,
                        'type': rtype, 'name': rname})
        print(f'  [{i}] size={rsz} offset={roff} type={rtype} name={rname!r}')

    ramdisk = bytes(d[off_ramdisk:off_ramdisk + vrs])
    f0 = ramdisk[entries[0]['offset']:entries[0]['offset'] + entries[0]['size']]
    f1 = ramdisk[entries[1]['offset']:entries[1]['offset'] + entries[1]['size']]

    tmp = tempfile.mkdtemp(prefix='vboot-')
    p_f0_lz4 = os.path.join(tmp, 'f0.lz4')
    p_f0_cpio = os.path.join(tmp, 'f0.cpio')
    p_f0_new_lz4 = os.path.join(tmp, 'f0.new.lz4')
    p_verify = os.path.join(tmp, 'verify.cpio')

    open(p_f0_lz4, 'wb').write(f0)
    lz4_d(p_f0_lz4, p_f0_cpio)
    cpio = bytearray(open(p_f0_cpio, 'rb').read())
    cpio_len_before = len(cpio)

    n = cpio.count(NEEDLE)
    print(f'\nfstab option occurrences in boot ramdisk: {n}')
    if n != 1:
        sys.exit(f'expected exactly 1 occurrence, found {n} -- aborting')

    j = cpio.find(NEEDLE)
    line_start = cpio.rfind(b'\n', 0, j) + 1
    line_end = cpio.find(b'\n', j)
    print('\n--- fstab line BEFORE ---')
    print(cpio[line_start:line_end].decode('utf-8', 'replace'))

    cpio[j:j + len(NEEDLE)] = b' ' * len(NEEDLE)

    print('\n--- fstab line AFTER (trailing spaces) ---')
    print(repr(cpio[line_start:line_end].decode('utf-8', 'replace')))

    assert len(cpio) == cpio_len_before, 'cpio length changed -- must stay identical'
    open(p_f0_cpio, 'wb').write(cpio)

    lz4_c(p_f0_cpio, p_f0_new_lz4)
    f0_new = open(p_f0_new_lz4, 'rb').read()

    # round-trip verify
    lz4_d(p_f0_new_lz4, p_verify)
    if open(p_verify, 'rb').read() != bytes(cpio):
        sys.exit('round-trip verification FAILED -- recompressed ramdisk differs')
    print(f'\nround-trip verify OK  ({len(f0)} -> {len(f0_new)} bytes compressed)')

    new_ramdisk = f0_new + f1
    new_vrs = len(new_ramdisk)

    out = bytearray(d[:off_ramdisk])                       # header page(s)
    out += new_ramdisk
    out += b'\x00' * (align(new_vrs, ps) - new_vrs)
    out += d[off_dtb:off_dtb + dtb_size]
    out += b'\x00' * (align(dtb_size, ps) - dtb_size)
    vrt_start_new = len(out)
    out += d[off_vrt:off_vrt + vrt_size]
    out += b'\x00' * (align(vrt_size, ps) - vrt_size)
    if bootconfig_size:
        out += d[off_bootcfg:off_bootcfg + bootconfig_size]
        out += b'\x00' * (align(bootconfig_size, ps) - bootconfig_size)

    struct.pack_into('<I', out, 24, new_vrs)               # vendor_ramdisk_size
    e0 = vrt_start_new + 0 * vrt_entry_size
    e1 = vrt_start_new + 1 * vrt_entry_size
    struct.pack_into('<II', out, e0, len(f0_new), 0)       # frag0 size, offset
    struct.pack_into('<II', out, e1, len(f1), len(f0_new))  # frag1 size, offset

    if len(out) < orig_total:
        out += b'\x00' * (orig_total - len(out))
    elif len(out) > orig_total:
        sys.exit(f'patched image {len(out)} exceeds original {orig_total} -- aborting')

    os.makedirs(os.path.dirname(DST), exist_ok=True)
    open(DST, 'wb').write(out)
    print(f'\nwrote {DST}  ({len(out)} bytes)')

    # re-parse the output as a sanity check
    v = open(DST, 'rb').read()
    vm, vhv, vps, _, _, vvrs = struct.unpack_from('<8sIIIII', v, 0)
    vvrt_size, vvrt_num, vvrt_es, _ = struct.unpack_from('<IIII', v, 2112)
    print(f'\nverify: magic={vm} ver={vhv} page={vps} vendor_ramdisk_size={vvrs} frags={vvrt_num}')
    ovrt = align(struct.unpack_from('<I', v, 2096)[0], vps) + align(vvrs, vps) + \
        align(struct.unpack_from('<I', v, 2100)[0], vps)
    for i in range(vvrt_num):
        eo = ovrt + i * vvrt_es
        rsz, roff, rtype = struct.unpack_from('<III', v, eo)
        print(f'  [{i}] size={rsz} offset={roff} type={rtype}')
    print('\nOK')


if __name__ == '__main__':
    main()
