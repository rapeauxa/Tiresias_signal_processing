filename = 'recording.bin';
fileInfo = dir(filename);
fileSize = fileInfo.bytes;

disp(['Opening recording file, size ',num2str(fileSize),' bytes.']);
fid = fopen(filename,'r');
frewind(fid);

disp("Checking file integrity...");
[sdRead,count] = fread(fid,1,'bool');
for i=1:3
    fread(fid,1,'uint8');
end
format = fread(fid,1,'int32');
frameNumber = fread(fid,1,'uint32');
bins = fread(fid,1,'int32');
datalen = fread(fid,1,'int32');
KFrameDataAddr = fread(fid,1,'uint32');
DFrameDataAddr = fread(fid,49,'uint32');
strLength = fread(fid,1,'int32');
timeStamp = fread(fid,1,'int64');
normalization_offset = fread(fid,1,'float');
normalization_nfactor = fread(fid,1,'float');
filter_normalization_factor = fread(fid,1,'float');

bytesPerFramePacket = 248+datalen*4*50;

disp(['First frame header information: data type ',num2str(format),', bin number ',num2str(bins),' equating to ',num2str(bytesPerFramePacket),' bytes per frame packet.']);

if mod(fileSize,bytesPerFramePacket) == 0
    disp('File integrity check is successful!');
    frewind(fid);
    frames = fileSize/bytesPerFramePacket*50;

    disp(['Reading ',num2str(frames),' frames...']);
    iData = zeros(frames,bins);
    qData = zeros(frames,bins);
    %buffer = zeros(2,bins);
    for i=1:(fileSize/bytesPerFramePacket)
        [~,~,~,~,~,~,~,~,~,~,~,~,iData(i*50-49:i*50,:),qData(i*50-49:i*50,:)] = sd_readframe(fid);
        %iData(i,:) = buffer(1,:);
        %qData(i,:) = buffer(2,:);
    end
else
    disp('File integrity check failed! Wrong size for calculated framePacket size');
    frames = 0;
end

fclose(fid);


