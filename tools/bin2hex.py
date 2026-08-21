#!/usr/bin/env python3
"""Convert a raw binary into one-byte-per-line Verilog readmemh format."""

from __future__ import annotations

import argparse
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument(
        "--size",
        type=int,
        help="pad the output to exactly this many bytes with 00",
    )
    args = parser.parse_args()

    data = args.input.read_bytes()
    if not data:
        raise SystemExit(f"input is empty: {args.input}")
    if args.size is not None:
        if len(data) > args.size:
            raise SystemExit(
                f"input is {len(data)} bytes, larger than --size {args.size}"
            )
        data = data.ljust(args.size, b"\x00")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("".join(f"{value:02X}\n" for value in data))
    print(f"{args.input}: {args.input.stat().st_size} bytes -> "
          f"{len(data)} hex bytes in {args.output}")


if __name__ == "__main__":
    main()
