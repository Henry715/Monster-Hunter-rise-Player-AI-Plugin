import socket
import json


if __name__=="__main__":
#    import socket

    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.connect(("127.0.0.1", 8080))

    buffer = ""

    while True:
        data = s.recv(4096)
        print(data)
        if not data:
            print("disconnected")
            break

        buffer += data.decode("utf-8")

        while "\n" in buffer:
            line, buffer = buffer.split("\n", 1)

            if line.strip():
                print("WORLD:", line)
    
