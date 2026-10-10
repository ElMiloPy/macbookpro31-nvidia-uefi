#!/usr/bin/env python3
# Auto-generated binary patch for nvidia 340.108 nv-kernel.o on Apple MacBook Pro 3,1 (UEFI Mode)
import sys, hashlib, shutil

ORIG_SHA256 = '3f96873b00a2252fbb6610eb3ecc315ccc5b685a2fc7dd61a24a43ccac34b12e'
PATCHED_SHA256 = 'a58ca34f9f211a9493e5f407d05a25232fd1636da4a58be9ae63a9470fb9663d'

PATCH_CHUNKS = [
    (0xfcf3f, bytes.fromhex('448b581c4585db7507c7401c80000000'), bytes.fromhex('4885c0740bc7401c8000000090909090')),
    (0x41eeb9, bytes.fromhex('488b83780400000fb640193cff7425'), bytes.fromhex('eb3290909090909090909090909090')),
    (0x41f0f0, bytes.fromhex('4883ec0831d24883ed0880be6c04000000488b8678040000c7450400000000750f89d04883c5084883c408c3'), bytes.fromhex('31c0c39090909090909090909090909090909090909090909090909090909090909090909090909090909090')),
    (0x41f2f0, bytes.fromhex('488b86780400005389d34889c2ff'), bytes.fromhex('89d0c39090909090909090909090')),
    (0x41f2ff, bytes.fromhex('7008000089da0fafd085c00f45da89d85bc3'), bytes.fromhex('909090909090909090909090909090909090')),
    (0x41f775, bytes.fromhex('498b877804000044887019'), bytes.fromhex('eb09909090909090909090')),
    (0x41f9a0, bytes.fromhex('4c8b8e780400004989c84889d14d8b99'), bytes.fromhex('31c0c390909090909090909090909090')),
    (0x41f9b1, bytes.fromhex('0800004c89ca41ffe3660f1f440000488b86780400000fb68030080000c3'), bytes.fromhex('90909090909090909090909090909031c0c3909090909090909090909090')),
    (0x422610, bytes.fromhex('415431c931d24989f4be8d000000534889fb4883ec08ff53204889df4889c6e80000000085c07517498b8424780400004c89e64889df4889c2ff'), bytes.fromhex('31c0c390909090909090909090909090909090909090909090909090909090909090909090909090909090909090909090909090909090909090')),
    (0x42264b, bytes.fromhex('380800004883c4085b415cc3660f1f8400000000004883ec08488b86780400004889c2ff'), bytes.fromhex('90909090909090909090909090909090909090909031c0c3909090909090909090909090')),
    (0x422670, bytes.fromhex('400800004883c408c30f1f800000000053488b86780400004889f34885c075045b31c0c34889c2ff'), bytes.fromhex('9090909090909090909090909090909031c0c3909090909090909090909090909090909090909090')),
    (0x422699, bytes.fromhex('9808000048c783780400000000000031c05bc30f1f4000'), bytes.fromhex('9090909090909090909090909090909090909090909090')),
    (0x5664f3, bytes.fromhex('41c745003000000041c74508eb02000048c7c600000000bf0400000031c0'), bytes.fromhex('4c89e64c89f2bf4f49425631c0eb0f909090909090909090909090909090')),
    (0x566516, bytes.fromhex('418b45044883c5185b415c415d415e415fc3'), bytes.fromhex('31c0418945004189450441894508eb029090')),
    (0x566d3b, bytes.fromhex('418945047422'), bytes.fromhex('31c041894500')),
    (0x566d42, bytes.fromhex('c7'), bytes.fromhex('89')),
    (0x566d44, bytes.fromhex('002500000041c74508ad0400004883c5205b415c415d415e415fe900000000'), bytes.fromhex('0441894508eb18909090909090909090909090909090909090909090909090')),
    (0xb46d78, bytes.fromhex('02'), bytes.fromhex('00')),
    (0xb46d7c, bytes.fromhex('5514'), bytes.fromhex('0000')),
    (0xbd53b0, bytes.fromhex('0b'), bytes.fromhex('00')),
    (0xbd53b4, bytes.fromhex('04'), bytes.fromhex('00')),
    (0xbd6760, bytes.fromhex('02'), bytes.fromhex('00')),
    (0xbd6764, bytes.fromhex('2244'), bytes.fromhex('0000')),
]

def apply_patch(target_path):
    print(f"Checking {target_path}...")
    with open(target_path, "rb") as f:
        data = bytearray(f.read())
    current_hash = hashlib.sha256(data).hexdigest()
    if current_hash == PATCHED_SHA256:
        print("Target is already patched!")
        return True
    if current_hash != ORIG_SHA256:
        print(f"Warning: SHA256 mismatch (got {current_hash}, expected {ORIG_SHA256}). Proceeding with byte verification...")
    
    # Backup
    shutil.copyfile(target_path, target_path + ".orig")
    
    for offset, old, new in PATCH_CHUNKS:
        actual = bytes(data[offset:offset+len(old)])
        if actual != old and actual != new:
            raise ValueError(f"Mismatch at {hex(offset)}: expected {old.hex()}, got {actual.hex()}")
        data[offset:offset+len(new)] = new
    
    new_hash = hashlib.sha256(data).hexdigest()
    assert new_hash == PATCHED_SHA256, f"Post-patch SHA256 mismatch: {new_hash}"
    with open(target_path, "wb") as f:
        f.write(data)
    print("Successfully applied all 23 binary patch chunks to nv-kernel.o!")
    return True

if __name__ == '__main__':
    target = sys.argv[1] if len(sys.argv) > 1 else "/usr/src/nvidia-340.108/nv-kernel.o"
    apply_patch(target)
