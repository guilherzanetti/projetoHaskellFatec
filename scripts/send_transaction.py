#!/usr/bin/env python3
"""
Bitcoin P2PKH transaction builder and broadcaster.
Uses ONLY libraries already installed by hdwallet (ecdsa, base58, pycryptodome).
No additional pip install needed.

Reads JSON from stdin:
  { "privateKey": "hex...", "senderAddress": "1...", "recipient": "1...",
    "amountBtc": 0.001, "feeRateSatVbyte": 10 }
Writes JSON to stdout:
  { "txHash": "abc123..." }  or  { "error": "message" }
"""
import hashlib
import json
import struct
import sys
import urllib.request
import urllib.error
from base58 import b58decode_check
from ecdsa import SigningKey, SECP256k1
from ecdsa.util import sigencode_der_canonize


# ── Bitcoin primitives ────────────────────────────────────────────────────────

def hash256(b: bytes) -> bytes:
    return hashlib.sha256(hashlib.sha256(b).digest()).digest()


def hash160(b: bytes) -> bytes:
    return hashlib.new("ripemd160", hashlib.sha256(b).digest()).digest()


def varint(n: int) -> bytes:
    if n < 0xFD:
        return struct.pack("<B", n)
    if n <= 0xFFFF:
        return b"\xfd" + struct.pack("<H", n)
    if n <= 0xFFFFFFFF:
        return b"\xfe" + struct.pack("<I", n)
    return b"\xff" + struct.pack("<Q", n)


def p2pkh_script(pkh: bytes) -> bytes:
    """OP_DUP OP_HASH160 <pkh> OP_EQUALVERIFY OP_CHECKSIG"""
    return b"\x76\xa9\x14" + pkh + b"\x88\xac"


# ── Key helpers ───────────────────────────────────────────────────────────────

def privkey_to_compressed_pubkey(hex_key: str) -> bytes:
    sk = SigningKey.from_string(bytes.fromhex(hex_key), curve=SECP256k1)
    vk = sk.get_verifying_key()
    x, y = vk.pubkey.point.x(), vk.pubkey.point.y()
    prefix = b"\x02" if y % 2 == 0 else b"\x03"
    return prefix + x.to_bytes(32, "big")


def address_to_pkh(address: str) -> bytes:
    payload = b58decode_check(address)
    if payload[0] != 0x00:
        raise ValueError(f"Endereço não é P2PKH mainnet: {address}")
    return payload[1:]  # 20-byte public key hash


# ── Network helpers ───────────────────────────────────────────────────────────

def fetch_utxos(address: str) -> list:
    url = f"https://blockstream.info/api/address/{address}/utxo"
    try:
        with urllib.request.urlopen(url, timeout=20) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"Blockstream UTXO fetch failed ({e.code}): {e.read().decode()}") from e


def broadcast_tx(raw_hex: str) -> str:
    url = "https://blockstream.info/api/tx"
    data = raw_hex.encode("utf-8")
    req = urllib.request.Request(
        url, data=data, method="POST",
        headers={"Content-Type": "text/plain"},
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return r.read().decode("utf-8").strip()
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"Broadcast failed ({e.code}): {e.read().decode()}") from e


# ── Transaction builder ───────────────────────────────────────────────────────

def build_and_sign(
    private_key_hex: str,
    sender_address: str,
    recipient_address: str,
    amount_sats: int,
    fee_sats: int,
    utxos: list,
) -> str:
    """Return raw signed transaction hex."""

    sk = SigningKey.from_string(bytes.fromhex(private_key_hex), curve=SECP256k1)
    compressed_pub = privkey_to_compressed_pubkey(private_key_hex)
    sender_pkh = hash160(compressed_pub)
    recipient_pkh = address_to_pkh(recipient_address)

    # Greedy UTXO selection (largest-first)
    selected: list = []
    total_in = 0
    needed = amount_sats + fee_sats
    for u in sorted(utxos, key=lambda x: x["value"], reverse=True):
        selected.append(u)
        total_in += u["value"]
        if total_in >= needed:
            break

    if total_in < needed:
        raise ValueError(
            f"Saldo insuficiente: {total_in} sats disponíveis, {needed} sats necessários "
            f"({amount_sats} envio + {fee_sats} taxa)"
        )

    change_sats = total_in - amount_sats - fee_sats

    # Build outputs list
    outputs = [(amount_sats, p2pkh_script(recipient_pkh))]
    if change_sats > 546:  # dust limit
        outputs.append((change_sats, p2pkh_script(sender_pkh)))

    def encode_outputs() -> bytes:
        r = varint(len(outputs))
        for value, script in outputs:
            r += struct.pack("<q", value) + varint(len(script)) + script
        return r

    VERSION = struct.pack("<I", 1)
    LOCKTIME = struct.pack("<I", 0)
    SIGHASH_ALL = struct.pack("<I", 1)
    n_inputs = len(selected)

    # Sign each input (SIGHASH_ALL: substitute input's scriptPubKey, blank others)
    script_sigs: list[bytes] = []
    for i, utxo in enumerate(selected):
        serialised_ins = varint(n_inputs)
        for j, u in enumerate(selected):
            txid_le = bytes.fromhex(u["txid"])[::-1]
            vout    = struct.pack("<I", u["vout"])
            seq     = b"\xff\xff\xff\xff"
            sub     = p2pkh_script(sender_pkh) if j == i else b""
            serialised_ins += txid_le + vout + varint(len(sub)) + sub + seq

        preimage = VERSION + serialised_ins + encode_outputs() + LOCKTIME + SIGHASH_ALL
        sig_der  = sk.sign_digest(hash256(preimage), sigencode=sigencode_der_canonize)
        sig_with_hashtype = sig_der + b"\x01"  # SIGHASH_ALL

        script_sig = (
            varint(len(sig_with_hashtype)) + sig_with_hashtype
            + varint(len(compressed_pub))  + compressed_pub
        )
        script_sigs.append(script_sig)

    # Assemble final signed transaction
    final_inputs = varint(n_inputs)
    for utxo, ssig in zip(selected, script_sigs):
        txid_le = bytes.fromhex(utxo["txid"])[::-1]
        vout    = struct.pack("<I", utxo["vout"])
        seq     = b"\xff\xff\xff\xff"
        final_inputs += txid_le + vout + varint(len(ssig)) + ssig + seq

    raw_tx = VERSION + final_inputs + encode_outputs() + LOCKTIME
    return raw_tx.hex()


# ── Entry point ───────────────────────────────────────────────────────────────

def main() -> None:
    try:
        payload = json.loads(sys.stdin.read())
        private_key_hex    = payload["privateKey"]
        sender_address     = payload["senderAddress"]
        recipient_address  = payload["recipient"]
        amount_btc         = float(payload["amountBtc"])
        fee_rate           = int(payload.get("feeRateSatVbyte", 10))
    except (KeyError, ValueError, json.JSONDecodeError) as e:
        print(json.dumps({"error": f"Input inválido: {e}"}))
        sys.exit(1)

    try:
        amount_sats = int(round(amount_btc * 1e8))
        if amount_sats <= 0:
            raise ValueError("O valor deve ser positivo")

        utxos = fetch_utxos(sender_address)
        if not utxos:
            raise ValueError("Nenhum UTXO encontrado. A carteira está vazia ou aguardando confirmações.")

        # Estimate tx size: 10 base + 148*n_inputs + 34*n_outputs (P2PKH)
        est_size = 10 + 148 * min(len(utxos), 5) + 34 * 2
        fee_sats = fee_rate * est_size

        raw_hex = build_and_sign(
            private_key_hex, sender_address, recipient_address,
            amount_sats, fee_sats, utxos,
        )

        tx_hash = broadcast_tx(raw_hex)
        print(json.dumps({"txHash": tx_hash}))

    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)


if __name__ == "__main__":
    main()
