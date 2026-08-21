#!/usr/bin/env python3
"""Convert a raw binary into one-byte-per-line Verilog readmemh format."""

from __future__ import annotations

import argparse
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    data = args.input.read_bytes()
    if not data:
        raise SystemExit(f"input is empty: {args.input}")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("".join(f"{value:02X}\n" for value in data))
    print(f"{args.input}: {len(data)} bytes -> {args.output}")


if __name__ == "__main__":
    main()
