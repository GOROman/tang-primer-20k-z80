#!/usr/bin/env python3
"""Generate the LUNA-based USB 2.0 UVC device core used by this project."""

from pathlib import Path
from types import SimpleNamespace

from amaranth import ClockDomain, ClockSignal, Elaboratable, Module, Mux, ResetSignal, Signal
from amaranth.back import verilog
from usb_protocol.emitters import DeviceDescriptorCollection
from usb_protocol.types import USBRequestRecipient, USBRequestType

from luna.gateware.stream.generator import StreamSerializer
from luna.gateware.usb.stream import USBInStreamInterface
from luna.gateware.usb.usb2.request import USBRequestHandler
from luna.usb2 import USBDevice, USBStreamInEndpoint


FRAME_INTERVAL = 333_333       # 30 fps, in 100 ns units
FRAME_SIZE = 640 * 480 * 2     # YUY2
MAX_PAYLOAD = 512
PROBE_LENGTH = 26              # UVC 1.1 probe/commit control size


def le16(value):
    return [value & 0xFF, (value >> 8) & 0xFF]


def le32(value):
    return [value & 0xFF, (value >> 8) & 0xFF, (value >> 16) & 0xFF, (value >> 24) & 0xFF]


def configuration_descriptor(descriptor_type=0x02, endpoint_size=MAX_PAYLOAD):
    """Return a UVC 1.1 configuration for one bulk YUY2 video stream."""
    vc_total = 13 + 18 + 9
    vs_total = 14 + 27 + 30 + 6
    total = 9 + 8 + 9 + vc_total + 9 + vs_total + 7
    bitrate = 640 * 480 * 16 * 30

    data = []
    data += [9, descriptor_type] + le16(total) + [2, 1, 0, 0x80, 50]
    data += [8, 0x0B, 0, 2, 0x0E, 0x03, 0x00, 0]  # Video IAD

    # VideoControl interface and class-specific descriptors.
    data += [9, 0x04, 0, 0, 0, 0x0E, 0x01, 0x00, 0]
    data += [13, 0x24, 0x01] + le16(0x0110) + le16(vc_total) + le32(60_000_000) + [1, 1]
    data += [18, 0x24, 0x02, 1] + le16(0x0201) + [0, 0] + le16(0) + le16(0) + le16(0) + [3, 0, 0, 0]
    data += [9, 0x24, 0x03, 2] + le16(0x0101) + [0, 1, 0]

    # VideoStreaming interface, YUY2 format, 640x480 at 30 fps.
    data += [9, 0x04, 1, 0, 1, 0x0E, 0x02, 0x00, 0]
    data += [14, 0x24, 0x01, 1] + le16(vs_total) + [0x81, 0, 2, 0, 0, 0, 1, 0]
    data += [27, 0x24, 0x04, 1, 1]
    data += [0x59, 0x55, 0x59, 0x32, 0x00, 0x00, 0x10, 0x00,
             0x80, 0x00, 0x00, 0xAA, 0x00, 0x38, 0x9B, 0x71]
    data += [16, 1, 0, 0, 0, 0]
    data += [30, 0x24, 0x05, 1, 0] + le16(640) + le16(480)
    data += le32(bitrate) + le32(bitrate) + le32(FRAME_SIZE)
    data += le32(FRAME_INTERVAL) + [1] + le32(FRAME_INTERVAL)
    data += [6, 0x24, 0x0D, 1, 1, 4]
    data += [7, 0x05, 0x81, 0x02] + le16(endpoint_size) + [0]

    assert len(data) == total
    return bytes(data)


def probe_bytes():
    data = []
    data += le16(1)                       # bmHint: fixed frame interval
    data += [1, 1]                        # format/frame index
    data += le32(FRAME_INTERVAL)
    data += le16(0) + le16(0) + le16(0) + le16(0) + le16(0)
    data += le32(FRAME_SIZE) + le32(MAX_PAYLOAD)
    assert len(data) == PROBE_LENGTH
    return data


class UVCRequestHandler(USBRequestHandler):
    SET_CUR = 0x01
    GET_CUR = 0x81
    GET_MIN = 0x82
    GET_MAX = 0x83
    GET_RES = 0x84
    GET_LEN = 0x85
    GET_INFO = 0x86
    GET_DEF = 0x87

    def __init__(self):
        super().__init__()
        self.streaming = Signal()

    def elaborate(self, platform):
        m = Module()
        interface = self.interface
        setup = interface.setup
        response = probe_bytes()

        m.submodules.serializer = serializer = StreamSerializer(
            data_length=PROBE_LENGTH,
            domain="usb",
            stream_type=USBInStreamInterface,
            max_length_width=6,
        )
        for index, value in enumerate(response):
            m.d.comb += serializer.data[index].eq(value)

        is_stream_interface = (
            (setup.type == USBRequestType.CLASS)
            & (setup.recipient == USBRequestRecipient.INTERFACE)
            & (setup.index[0:8] == 1)
        )
        selector = setup.value[8:16]
        is_probe_or_commit = (selector == 1) | (selector == 2)

        with m.If(is_stream_interface):
            with m.If(is_probe_or_commit):
                m.d.comb += interface.claim.eq(1)

                with m.If(setup.request == self.SET_CUR):
                    with m.If(interface.rx_ready_for_response):
                        m.d.comb += interface.handshakes_out.ack.eq(1)
                    with m.If(interface.status_requested):
                        m.d.comb += self.send_zlp()
                        with m.If(selector == 2):
                            m.d.usb += self.streaming.eq(1)

                with m.Elif(
                    (setup.request == self.GET_CUR)
                    | (setup.request == self.GET_MIN)
                    | (setup.request == self.GET_MAX)
                    | (setup.request == self.GET_RES)
                    | (setup.request == self.GET_DEF)
                ):
                    m.d.comb += [
                        serializer.stream.attach(interface.tx),
                        serializer.max_length.eq(Mux(setup.length < PROBE_LENGTH, setup.length, PROBE_LENGTH)),
                    ]
                    with m.If(interface.data_requested):
                        m.d.comb += serializer.start.eq(1)
                    with m.If(interface.status_requested):
                        m.d.comb += interface.handshakes_out.ack.eq(1)

                with m.Elif(setup.request == self.GET_LEN):
                    m.d.comb += [
                        serializer.stream.attach(interface.tx),
                        serializer.data[0].eq(PROBE_LENGTH),
                        serializer.data[1].eq(0),
                        serializer.max_length.eq(2),
                    ]
                    with m.If(interface.data_requested):
                        m.d.comb += serializer.start.eq(1)
                    with m.If(interface.status_requested):
                        m.d.comb += interface.handshakes_out.ack.eq(1)

                with m.Elif(setup.request == self.GET_INFO):
                    m.d.comb += [
                        serializer.stream.attach(interface.tx),
                        serializer.data[0].eq(3),
                        serializer.max_length.eq(1),
                    ]
                    with m.If(interface.data_requested):
                        m.d.comb += serializer.start.eq(1)
                    with m.If(interface.status_requested):
                        m.d.comb += interface.handshakes_out.ack.eq(1)

                with m.Else():
                    m.d.comb += interface.handshakes_out.stall.eq(1)

        return m


class InterfaceRequestHandler(USBRequestHandler):
    """Implement GET_INTERFACE and SET_INTERFACE for the UVC interfaces."""

    def elaborate(self, platform):
        m = Module()
        interface = self.interface
        setup = interface.setup

        m.submodules.serializer = serializer = StreamSerializer(
            data_length=1, domain="usb", stream_type=USBInStreamInterface, max_length_width=1
        )
        m.d.comb += [serializer.data[0].eq(0), serializer.max_length.eq(1)]

        is_request = (
            (setup.type == USBRequestType.STANDARD)
            & (setup.recipient == USBRequestRecipient.INTERFACE)
            & ((setup.request == 0x0A) | (setup.request == 0x0B))
        )
        with m.If(is_request):
            m.d.comb += interface.claim.eq(1)
            with m.If(setup.request == 0x0A):
                m.d.comb += serializer.stream.attach(interface.tx)
                with m.If(interface.data_requested):
                    m.d.comb += serializer.start.eq(1)
                with m.If(interface.status_requested):
                    m.d.comb += interface.handshakes_out.ack.eq(1)
            with m.Else():
                with m.If(interface.status_requested):
                    m.d.comb += self.send_zlp()

        return m


class USBUVCCore(Elaboratable):
    def __init__(self):
        self.usb_clk = Signal()
        self.usb_rst = Signal()
        self.ulpi_dir = Signal()
        self.ulpi_nxt = Signal()
        self.ulpi_data_i = Signal(8)
        self.ulpi_stp = Signal()
        self.ulpi_data_o = Signal(8)
        self.ulpi_data_oe = Signal()
        self.stream_valid = Signal()
        self.stream_ready = Signal()
        self.stream_first = Signal()
        self.stream_last = Signal()
        self.stream_payload = Signal(8)
        self.frame_start = Signal()
        self.streaming = Signal()

    def create_descriptors(self):
        descriptors = DeviceDescriptorCollection()
        with descriptors.DeviceDescriptor() as d:
            d.bcdUSB = 2.00
            d.bDeviceClass = 0xEF
            d.bDeviceSubclass = 0x02
            d.bDeviceProtocol = 0x01
            d.bMaxPacketSize0 = 64
            d.idVendor = 0x1209
            d.idProduct = 0x0001
            d.bcdDevice = 1.00
            d.iManufacturer = "GOROman"
            d.iProduct = "Tang Primer 20K PSG Debug Camera"
            d.iSerialNumber = "TP20K-Z80-0001"
            d.bNumConfigurations = 1
        descriptors.add_descriptor(configuration_descriptor())
        descriptors.add_descriptor(bytes([10, 6, 0x00, 0x02, 0xEF, 0x02, 0x01, 64, 1, 0]))
        descriptors.add_descriptor(configuration_descriptor(0x07, 64), descriptor_type=0x07)
        return descriptors

    def elaborate(self, platform):
        m = Module()
        m.domains.usb = ClockDomain("usb", async_reset=True)
        m.d.comb += [ClockSignal("usb").eq(self.usb_clk), ResetSignal("usb").eq(self.usb_rst)]

        data = SimpleNamespace(i=self.ulpi_data_i, o=Signal(8), oe=Signal())
        direction = SimpleNamespace(i=self.ulpi_dir)
        nxt = SimpleNamespace(i=self.ulpi_nxt)
        stp = SimpleNamespace(o=Signal())
        ulpi = SimpleNamespace(data=data, dir=direction, nxt=nxt, stp=stp)
        m.d.comb += [
            self.ulpi_data_o.eq(data.o),
            self.ulpi_data_oe.eq(data.oe),
            self.ulpi_stp.eq(stp.o),
        ]

        m.submodules.usb = usb = USBDevice(bus=ulpi, handle_clocking=False)
        skip_interface = lambda setup: (
            (setup.type == USBRequestType.STANDARD)
            & (setup.recipient == USBRequestRecipient.INTERFACE)
            & ((setup.request == 0x0A) | (setup.request == 0x0B))
        )
        control = usb.add_standard_control_endpoint(self.create_descriptors(), skiplist=(skip_interface,))
        uvc_handler = UVCRequestHandler()
        control.add_request_handler(uvc_handler)
        control.add_request_handler(InterfaceRequestHandler())

        endpoint = USBStreamInEndpoint(endpoint_number=1, max_packet_size=MAX_PAYLOAD)
        usb.add_endpoint(endpoint)
        m.d.comb += [
            endpoint.stream.valid.eq(self.stream_valid),
            endpoint.stream.first.eq(self.stream_first),
            endpoint.stream.last.eq(self.stream_last),
            endpoint.stream.payload.eq(self.stream_payload),
            self.stream_ready.eq(endpoint.stream.ready),
            usb.connect.eq(1),
            self.streaming.eq(uvc_handler.streaming),
        ]

        accumulator = Signal(range(1000))
        m.d.usb += self.frame_start.eq(0)

        with m.If(usb.new_frame & uvc_handler.streaming):
            with m.If(accumulator >= 970):
                m.d.usb += [accumulator.eq(accumulator + 30 - 1000), self.frame_start.eq(1)]
            with m.Else():
                m.d.usb += accumulator.eq(accumulator + 30)

        return m


def main():
    core = USBUVCCore()
    ports = [
        core.usb_clk, core.usb_rst,
        core.ulpi_dir, core.ulpi_nxt, core.ulpi_data_i,
        core.ulpi_stp, core.ulpi_data_o, core.ulpi_data_oe,
        core.stream_valid, core.stream_ready, core.stream_first,
        core.stream_last, core.stream_payload,
        core.frame_start, core.streaming,
    ]
    output = verilog.convert(core, name="usb_uvc_core", ports=ports, emit_src=False)
    path = Path("rtl/generated/usb_uvc_core.v")
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as generated:
        generated.write(output)
    print(f"Generated {path}")


if __name__ == "__main__":
    main()
