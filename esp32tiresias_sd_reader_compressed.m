%ESP32 TIRESIAS binary recording file reader for huffman-compressed data
%Author: Adrien Rapeaux
%First release 31th August 2022

%TODOs: change data integrity check to parse the whole file, looking for
%every framePacket header, then reading ahead by the corresponding amount
%of data, as framePackets could have variable lengths in the future within
%the same file.

clc
clear variables

filename = 'recording_compressed2.bin'; %Input filename of the recording here
fileInfo = dir(filename);
fileSize = fileInfo.bytes;

disp(['Opening recording file, size ',num2str(fileSize),' bytes.']);
fid = fopen(filename,'r');
frewind(fid);

disp("Checking file integrity...");

framePackets = 0;
prevFrameNumber = 1;
% reading a frame packet header
while(~feof(fid))
[sdRead,count] = fread(fid,1,'bool');
for i=1:3
    fread(fid,1,'uint8');
end
format = fread(fid,1,'uint32');
frameNumber(framePackets+1,1) = fread(fid,1,'uint32');
if ~((prevFrameNumber == frameNumber(framePackets+1,1)) || (prevFrameNumber+50 == frameNumber(framePackets+1,1)))
    disp(['File integrity check failed! Frame number was ' num2str(frameNumber(framePackets+1,1)) ' but ' num2str(prevFrameNumber) ' was read previously']); 
    disp(['Process stopped at ' num2str(ftell(fid)) ' bytes.'])
    break;
end
prevFrameNumber = frameNumber(framePackets+1,1);
bins = fread(fid,1,'int32');
datalen = fread(fid,1,'int32');
KFrameDataAddr = fread(fid,1,'uint32');
DFrameDataAddr = fread(fid,49,'uint32');
bytes = fread(fid,1,'uint32');
timeStamp = fread(fid,1,'int64');
normalization_offset = fread(fid,1,'float');
normalization_nfactor = fread(fid,1,'float');
filter_normalization_factor = fread(fid,1,'float');

fread(fid,(bytes/4)+1,'uint32');
framePackets = framePackets +1;
end
frewind(fid)
fclose(fid);
disp(['Successfully read ' num2str(framePackets*50) ' frames']);


%reading a frame header
[sdRead,count] = fread(fid,1,'bool');
for i=1:3
    fread(fid,1,'uint8');
end
format = fread(fid,1,'uint32');
frameNumber = fread(fid,1,'uint32');
bins = fread(fid,1,'int32');
datalen = fread(fid,1,'int32');
KFrameDataAddr = fread(fid,1,'uint32');
DFrameDataAddr = fread(fid,49,'uint32');
bytes = fread(fid,1,'uint32');
timeStamp = fread(fid,1,'int64');
normalization_offset = fread(fid,1,'float');
normalization_nfactor = fread(fid,1,'float');
filter_normalization_factor = fread(fid,1,'float');

fread(fid,bytes+4,'uint8');



%everything onwards from here is obsolete. We aso need to huffman-decode 
%the data. The data is guaranteed to be a multiple of 32 bits so we can use
%uint32 as type for fread.
data = uint32(fread(fid,bytes/4,'uint32'));

%WIP: we use the python decoder (only for single frame packets at a time)
%we need to create a text file with comma separated values.
fclose(fid);
fout = fopen('out.txt','w');

for i=1:length(data)
    fprintf(fout,'%u, ',data(i));
end

fclose(fout);

%insert huffman decode here


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


