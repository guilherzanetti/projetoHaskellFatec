#!/usr/bin/env python3
"""
Bitcoin BIP39/BIP44 wallet generator.
Uses the hdwallet library to generate a 12-word mnemonic, derive
the standard BIP44 path (m/44'/0'/0'/0/0), and output the address
and private key as JSON to stdout.

Install dependencies: pip install -r requirements.txt
"""
import json
import sys


def main() -> None:
    try:
        from hdwallet import BIP44HDWallet
        from hdwallet.cryptocurrencies import BitcoinMainnet
        from hdwallet.utils import generate_mnemonic
    except ImportError as e:
        error = f"Missing dependency: {e}. Run: pip install hdwallet"
        json.dump({"error": error}, sys.stderr)
        sys.exit(1)

    try:
        mnemonic = generate_mnemonic(language="english", strength=128)

        wallet: BIP44HDWallet = BIP44HDWallet(cryptocurrency=BitcoinMainnet)
        wallet.from_mnemonic(mnemonic=mnemonic, language="english", passphrase="")
        wallet.clean_derivation()
        wallet.from_path(path="m/44'/0'/0'/0/0")

        result = {
            "mnemonic": mnemonic,
            "address": wallet.address(),
            "privateKey": wallet.private_key(),
        }
        print(json.dumps(result))

    except Exception as e:
        json.dump({"error": str(e)}, sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
