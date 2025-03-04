class PDU:
    #this class represetns a general packet data unit.
    def __init__(self, data: bytes):
        self.data = data  # The actual PDU data
        self.len = len(data)  # PDULENGTH
        self.watermark = self.len  # Watermark set to length initially
        self.curPos = 0  # Current parse position 0..len
        self.curBitPos = 0  # Current position within a bit 0..8
        self.remaining = self.len  # Used when parsing flags
        self.header = None  # Placeholder for header information

    def read_pdu(file_path):
        #read the PDU from a file
        try:
            with open(file_path, 'rb') as file:
                data = file.read()
            return PDU(data)
        except FileNotFoundError:
            print("Error: File not found.")
            return None
        except IOError as e:
            print(f"I/O error: {e}")
            return None

    def get_bits(self, num_bits):
        #get the next bits and traverse the packet
        num_bytes = (num_bits + 7) // 8  # Ensure enough bytes are read
        if self.curPos + num_bytes > self.len:
            raise ValueError("Not enough data remaining in PDU.")
        
        value = int.from_bytes(self.data[self.curPos:self.curPos + num_bytes], 'big')
        value >>= (num_bytes * 8 - num_bits)  # Adjust for bit alignment
        self.curPos += num_bytes
        return value

    def get_8_bits(self):
        return self.get_bits(8)

    def get_16_bits(self):
        return self.get_bits(16)

    def get_24_bits(self):
        return self.get_bits(24)

    def get_32_bits(self):
        return self.get_bits(32)

    def get_48_bits(self):
        return self.get_bits(48)

    def get_64_bits(self):
        return self.get_bits(64)

if __name__ == "__main__":
    file_path = input("Enter the file path: ")
    pdu = PDU.read_pdu(file_path)
    
    if pdu is not None:
        print(f"PDU Read: {pdu.len} bytes.")
