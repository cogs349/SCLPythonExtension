from packet import PDU

class PDU_ARP(PDU):
    """
    A class representing an ARP packet based on the provided ASN.1 specification.
    """
    def __init__(self, data: bytes):
        super().__init__(data)
        self.hwType = self.get_16_bits()
        self.protocolType = self.get_16_bits()
        self.hwSize = self.get_8_bits()
        self.protocolSize = self.get_8_bits()
        self.opcode = self.get_16_bits()
        self.senderMAC = self.get_mac_address()
        self.senderIP = self.get_32_bits()
        self.targetMAC = self.get_mac_address()
        self.targetIP = self.get_32_bits()
    
    def get_mac_address(self):
        """Retrieves a MAC address (6 bytes)."""
        mac = self.data[self.curPos:self.curPos + 6]
        self.curPos += 6
        return ':'.join(f"{byte:02x}" for byte in mac)

if __name__ == "__main__":
    file_path = input("Enter the file path: ")
    pdu = PDU_ARP.read_pdu(file_path)
    
    if pdu is not None:
        print(f"PDU_ARP Read: {pdu.len} bytes.")
        print(f"Hardware Type: {pdu.hwType}")
        print(f"Protocol Type: {pdu.protocolType}")
        print(f"Hardware Size: {pdu.hwSize}")
        print(f"Protocol Size: {pdu.protocolSize}")
        print(f"Opcode: {pdu.opcode}")
        print(f"Sender MAC: {pdu.senderMAC}")
        print(f"Sender IP: {pdu.senderIP}")
        print(f"Target MAC: {pdu.targetMAC}")
        print(f"Target IP: {pdu.targetIP}")
