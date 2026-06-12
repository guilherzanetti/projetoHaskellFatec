#!/usr/bin/env python3
"""
Import an existing Bitcoin wallet from a BIP39 mnemonic phrase.
Reads JSON from stdin: {"mnemonic": "word1 word2 ... word12"}
Writes JSON to stdout: {"mnemonic": "...", "address": "...", "privateKey": "..."}
"""
import json
import sys


def main() -> None:
    try:
        payload = json.loads(sys.stdin.read())
        mnemonic = payload.get("mnemonic", "").strip()
    except (json.JSONDecodeError, AttributeError) as e:
        print(json.dumps({"error": f"Invalid input JSON: {e}"}))
        sys.exit(1)

    if not mnemonic:
        print(json.dumps({"error": "Mnemônico vazio"}))
        sys.exit(1)

    words = mnemonic.split()
    if len(words) not in (12, 15, 18, 21, 24):
        print(json.dumps({
            "error": f"Mnemônico inválido: {len(words)} palavras. Esperado: 12, 15, 18, 21 ou 24."
        }))
        sys.exit(1)

    try:
        from hdwallet import BIP44HDWallet
        from hdwallet.cryptocurrencies import BitcoinMainnet

        wallet: BIP44HDWallet = BIP44HDWallet(cryptocurrency=BitcoinMainnet)
        wallet.from_mnemonic(mnemonic=mnemonic, language="english", passphrase="")
        wallet.clean_derivation()
        wallet.from_path(path="m/44'/0'/0'/0/0")

        print(json.dumps({
            "mnemonic": mnemonic,
            "address": wallet.address(),
            "privateKey": wallet.private_key(),
        }))
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)


if __name__ == "__main__":
    main()
