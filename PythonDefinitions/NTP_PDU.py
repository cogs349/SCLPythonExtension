#this is what we want our output to look like when you pass an NTP
#packet specification to it. note that the print statements may not be
#as unique to eachother as they are in this file. It is just for reference.

from packet import PDU

class PDU_NTP(PDU):
    def __init__(self, data: bytes):
        super().__init__(data)
        self.flags = self.get_8_bits()
        self.peerStratum = self.get_8_bits()
        self.peerInterval = self.get_8_bits()
        self.peerPrecision = self.get_8_bits()
        self.rootDelay = self.get_32_bits()
        self.rootDispersion = self.get_32_bits()
        self.referenceId = self.get_32_bits()
        self.referenceTS = self.get_64_bits()
        self.originTS = self.get_64_bits()
        self.receiveTS = self.get_64_bits()
        self.transmitTS = self.get_64_bits()

if __name__ == "__main__":
    file_path = input("Enter the file path: ")
    pdu = PDU_NTP.read_pdu(file_path)
    
    if pdu is not None:
        print(f"PDU_NTP Read: {pdu.len} bytes.")
        print(f"Flags: {pdu.flags}")
        print(f"Peer Stratum: {pdu.peerStratum}")
        print(f"Peer Interval: {pdu.peerInterval}")
        print(f"Peer Precision: {pdu.peerPrecision}")
        print(f"Root Delay: {pdu.rootDelay}")
        print(f"Root Dispersion: {pdu.rootDispersion}")
        print(f"Reference ID: {pdu.referenceId}")
        print(f"Reference Timestamp: {pdu.referenceTS}")
        print(f"Origin Timestamp: {pdu.originTS}")
        print(f"Receive Timestamp: {pdu.receiveTS}")
        print(f"Transmit Timestamp: {pdu.transmitTS}")
