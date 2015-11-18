function testReceiveMessage()
sock = igtlConnect('127.0.0.1',18944);
receiver = OpenIGTLinkMessageReceiver(sock, @onRxStringMessage, @onRxTransformMessage, @onRxNDArrayMessage, @onRxImageMsg);

    for i=1:10
        receiver.readMessage();
    end
    
    igtlDisconnect(sock);

end

function onRxStringMessage(deviceName, message)
  disp('received  STRING message');
  disp(deviceName);
  disp(message);
end

function onRxTransformMessage(deviceName, transform)
  disp('received  TRANSFORM message');
  disp(deviceName);
  disp( transform );
end

function onRxNDArrayMessage()
end