#!/usr/bin/env python3
"""Prepare the upstream Gowin HDMI transmitter for Gowin EDA synthesis."""

from pathlib import Path


SOURCE = Path("third_party/hdmi_tx/hdl/hdmi_tx_gw.vhd")
OUTPUT = Path("impl/generated/hdmi_tx_gw.vhd")
ARCHITECTURE = "architecture RTL of hdmi_tx_pdiff_submodule is\n"
HELPERS = (
    ARCHITECTURE
    + "\t-- Missing from upstream hdmi_tx_gw.vhd revision 86c99f8.\n"
    + "\tfunction is_true(S:std_logic) return boolean is begin return(S='1'); end;\n"
    + "\tfunction is_false(S:std_logic) return boolean is begin return(S='0'); end;\n"
)


def main() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    if source.count(ARCHITECTURE) != 1:
        raise SystemExit(f"expected one Gowin serializer architecture in {SOURCE}")

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(source.replace(ARCHITECTURE, HELPERS), encoding="utf-8")
    print(f"Prepared {OUTPUT} from {SOURCE}")


if __name__ == "__main__":
    main()
