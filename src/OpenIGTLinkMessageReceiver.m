% OpenIGTLink server that executes the received string commands
function receiver = OpenIGTLinkMessageReceiver(sock, onRxStringMsg, onRxTransformMsg, onRxNDArrayMsg, onRxImageMsg)
    global onRxStringMessage onRxTransformMessage onRxNDArrayMessage, onRxImageMsg;
    onRxStringMessage = onRxStringMsg;
    onRxTransformMessage = onRxTransformMsg;
    onRxImageMessage = onRxImageMsg;
    onRxNDArrayMessage = onRxNDArrayMsg;

    global socket;
    socket = sock;
    
    global timeout;
    timeout = 500;
   
    receiver.readMessage = @readMessage;
end

function [name data] = readMessage()
    global onRxStringMessage onRxTransformMessage onRxImageMessage onRxNDArrayMessage;

    msg = ReadOpenIGTLinkMessage();
    
    %look at the message type and call appropriate function supplied as
    %arguments
    messageType = char(msg.dataTypeName);
    messageType = deblank(messageType);
    
    if strcmpi(messageType, 'STRING')
        [name data] = handleStringMessage(msg, onRxStringMessage );
    elseif strcmpi(messageType, 'TRANSFORM')
        [name data]=handleTransformMessage(msg, onRxTransformMessage );
    elseif strcmpi(messageType, 'IMAGE')
        [name data]=handleImageMessage(msg, onRxImageMessage );
    elseif strcmpi(messageType, 'NDARRAY')
        [name data]=handleNDArrayMessage(msg, onRxNDArrayMessage );
    end

end

function [name message] = handleStringMessage(msg, onRxStringMessage)
    if (length(msg.body)<5)
        disp('Error: STRING message received with incomplete contents')
        msg.string='';
        return
    end        
    strMsgEncoding=convertFromUint8VectorToUint16(msg.body(1:2));
    if (strMsgEncoding~=3)
        disp(['Warning: STRING message received with unknown encoding ',num2str(strMsgEncoding)])
    end
    strMsgLength=convertFromUint8VectorToUint16(msg.body(3:4));
    msg.string=char(msg.body(5:4+strMsgLength));
    name = msg.deviceName;
    message = msg.string;
    %onRxStringMessage(msg.deviceName, msg.string);
end

function [name trans] = handleTransformMessage(msg, onRxTransformMessage)
    transform = diag([1 1 1 1]);
    k=1;
    for i=1:4
        for j=1:3
            transform(j,i) = convertFromUint8VectorToFloat32(msg.body(4*(k-1) +1:4*k));
            k = k+1;
        end
    end
    name = msg.deviceName;
    trans = transform;
    %onRxTransformMessage(msg.deviceName , transform);
end

function [name data] = handleImageMessage(msg, onRxStringMessage)
    body = msg.body;
    i=1;
    
    versionNumber = uint8(body(i)); i = i + 2;
    numberOfComponents = uint8(body(i)); i = i + 1;
    scalarType = uint8(body(i)); i = i + 1; % 2:int8 3:uint8 4:int16 5:uint16 6:int32 7:uint32 10:float32 11:float64)
    endian = uint8(body(i)); i = i + 1; % 1:BIG 2:LITTLE
    coordinate = uint8(body(i)); i = i + 1; % 1:RAS 2:LPS
    
    volumeSizeI = convertFromUint8VectorToUint16(body(i:i+1));i = i + 2;
    volumeSizeJ = convertFromUint8VectorToUint16(body(i:i+1));i = i + 2;
    volumeSizeK = convertFromUint8VectorToUint16(body(i:i+1));i = i + 2;
    
    data.ijkToXyz = eye(4);
    
    data.ijkToXyz(1,1) = convertFromUint8VectorToFloat32(body(i:i+3));i = i + 4;
    data.ijkToXyz(2,1) = convertFromUint8VectorToFloat32(body(i:i+3));i = i + 4;
    data.ijkToXyz(3,1) = convertFromUint8VectorToFloat32(body(i:i+3));i = i + 4;
    
    data.ijkToXyz(1,2) = convertFromUint8VectorToFloat32(body(i:i+3));i = i + 4;
    data.ijkToXyz(2,2) = convertFromUint8VectorToFloat32(body(i:i+3));i = i + 4;
    data.ijkToXyz(3,2) = convertFromUint8VectorToFloat32(body(i:i+3));i = i + 4;
    
    data.ijkToXyz(1,3) = convertFromUint8VectorToFloat32(body(i:i+3));i = i + 4;
    data.ijkToXyz(2,3) = convertFromUint8VectorToFloat32(body(i:i+3));i = i + 4;
    data.ijkToXyz(3,3) = convertFromUint8VectorToFloat32(body(i:i+3));i = i + 4;
    
    positionX = convertFromUint8VectorToFloat32(body(i:i+3));i = i + 4;
    positionY = convertFromUint8VectorToFloat32(body(i:i+3));i = i + 4;
    positionZ = convertFromUint8VectorToFloat32(body(i:i+3));i = i + 4;

    % Save the transform that is embedded in the IMAGE message into the tracked frame
    % igtl origin is in the image center
    centerOriginToCornerOriginTransform=eye(4);
    centerOriginToCornerOriginTransform(1:3,4) = [ -volumeSizeI/2; -volumeSizeJ/2; -volumeSizeK/2 ];
    data.ijkToXyz = data.ijkToXyz * centerOriginToCornerOriginTransform;

    subvolumeOriginI = convertFromUint8VectorToUint16(body(i:i+1)); i = i + 2;
    subvolumeOriginJ = convertFromUint8VectorToUint16(body(i:i+1)); i = i + 2;
    subvolumeOriginK = convertFromUint8VectorToUint16(body(i:i+1)); i = i + 2;

    subVolumeSizeI = convertFromUint8VectorToUint16(body(i:i+1)); i = i + 2;
    subVolumeSizeJ = convertFromUint8VectorToUint16(body(i:i+1)); i = i + 2;
    subVolumeSizeK = convertFromUint8VectorToUint16(body(i:i+1)); i = i + 2;
    
    data.pixelData = zeros(volumeSizeI, volumeSizeJ, volumeSizeK);
    type = '';
    typeSize = 1;
    
    if (scalarType == 2)
        type = 'int8';
        typeSize = 1;
    elseif (scalarType == 3)
        type = 'uint8';
        typeSize = 1;
    elseif (scalarType == 4)
        type = 'int16';
        typeSize = 2;
    elseif (scalarType == 5)
        type = 'uint16';
        typeSize = 2;
    elseif (scalarType == 6)
        type = 'int32';
        typeSize = 4;
    elseif (scalarType == 7)
        type = 'uint32';
        typeSize = 4;
    elseif (scalarType == 10)
        type = 'float32';
        typeSize = 4;
    elseif (scalarType == 11)
        type = 'float64';
        typeSize = 8;
    else
        return
    end
        
    for kIndex=1:volumeSizeK
      for jIndex=1:volumeSizeJ
        for iIndex=1:volumeSizeI
            data.pixelData(iIndex,jIndex,kIndex) = typecast(uint8(body(i:i+(typeSize-1))), type); i = i + typeSize;
        end  
      end
    end
    
    name = msg.deviceName
    %onRxStringMessage(msg.deviceName, msg.string);
end

function handleNDArrayMessage(msg, onRxNDArrayMessage)
  print("handleNDArrayMessage is not yet implemented");
end

%%  Parse OpenIGTLink messag header
% http://openigtlink.org/protocols/v2_header.html    
function parsedMsg=ParseOpenIGTLinkMessageHeader(rawMsg)
    parsedMsg.versionNumber=convertFromUint8VectorToUint16(rawMsg(1:2));
    parsedMsg.dataTypeName=char(rawMsg(3:14));
    parsedMsg.deviceName=char(rawMsg(15:34));
    parsedMsg.timestamp=convertFromUint8VectorToInt64(rawMsg(35:42));
    parsedMsg.bodySize=convertFromUint8VectorToInt64(rawMsg(43:50));
    parsedMsg.bodyCrc=convertFromUint8VectorToInt64(rawMsg(51:58));
end

function msg=ReadOpenIGTLinkMessage()
    global timeout;
    openIGTLinkHeaderLength=58;
    headerData=ReadWithTimeout(openIGTLinkHeaderLength, timeout);
    if (length(headerData)==openIGTLinkHeaderLength)
        msg=ParseOpenIGTLinkMessageHeader(headerData);
        msg.body=ReadWithTimeout(msg.bodySize, timeout);            
    else
        error('ERROR: Timeout while waiting receiving OpenIGTLink message header')
    end
end    
      
function data=ReadWithTimeout(requestedDataLength, timeoutSec)
    import java.net.Socket
    import java.io.*
    import java.net.ServerSocket
    
    global socket;
    
    % preallocate to improve performance
    data=zeros(1,requestedDataLength,'uint8');
    signedDataByte=int8(0);
    bytesRead=0;
    while(bytesRead<requestedDataLength)    
        % Computing (requestedDataLength-bytesRead) is an int64 operation, which may not be available on Matlab R2009 and before
        int64arithmeticsSupported=~isempty(find(strcmp(methods('int64'),'minus')));
        if int64arithmeticsSupported
            % Full 64-bit arithmetics
            bytesToRead=min(socket.inputStream.available, requestedDataLength-bytesRead);
        else
            % Fall back to floating point arithmetics
            bytesToRead=min(socket.inputStream.available, double(requestedDataLength)-double(bytesRead));
        end  
        if (bytesRead==0 && bytesToRead>0)
            % starting to read message header
            tstart=tic;
        end
        for i = bytesRead+1:bytesRead+bytesToRead
            signedDataByte = DataInputStream(socket.inputStream).readByte;
            if signedDataByte>=0
                data(i) = signedDataByte;
            else
                data(i) = bitcmp(-signedDataByte,'uint8')+1;
            end
        end            
        bytesRead=bytesRead+bytesToRead;
        if (bytesRead>0 && bytesRead<requestedDataLength)
            % check if the reading of the header has timed out yet
            timeElapsedSec=toc(tstart);
            if(timeElapsedSec>timeoutSec)
                % timeout, it should not happen
                % remove the unnecessary preallocated elements
                data=data(1:bytesRead);
                break
            end
        end
    end
end


function result=convertFromUint8VectorToUint16(uint8Vector)
  result=int32(uint8Vector(1))*256+int32(uint8Vector(2));
end

function result=convertFromUint8VectorToFloat32(uint8Vector)
    binVal = '';
    for i=1:4
        binVal = strcat(binVal, dec2bin(uint8Vector(i),8));
    end
    q = quantizer('float', [32 8]); % this is IEE 754
    result = bin2num(q, binVal);
end 

function result=convertFromUint8VectorToFloat64(uint8Vector)
    binVal = '';
    for i=1:8
        binVal = strcat(binVal, dec2bin(uint8Vector(i),16));
    end
    q = quantizer('double', [64 16]); % this is IEE 754
    result = bin2num(q, binVal);
end 

function result=convertFromUint8VectorToInt64(uint8Vector)
  multipliers = [256^7 256^6 256^5 256^4 256^3 256^2 256^1 1];
  % Matlab R2009 and earlier versions don't support int64 arithmetics.
  int64arithmeticsSupported=~isempty(find(strcmp(methods('int64'),'mtimes')));
  if int64arithmeticsSupported
    % Full 64-bit arithmetics
    result = sum(int64(uint8Vector).*int64(multipliers));
  else
    % Fall back to floating point arithmetics: compute result with floating
    % point type and convert the end result to int64
    % (it should be precise enough for realistic file sizes)
    result = int64(sum(double(uint8Vector).*multipliers));
  end  
end 

function selectedByte=getNthByte(multibyte, n)
  selectedByte=uint8(mod(floor(multibyte/256^n),256));
end



