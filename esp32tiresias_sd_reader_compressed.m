%ESP32 TIRESIAS binary recording file reader for huffman-compressed data
%Author: Adrien Rapeaux
%First release 31th August 2022

%TODOs: change data integrity check to parse the whole file, looking for
%every framePacket header, then reading ahead by the corresponding amount
%of data, as framePackets could have variable lengths in the future within
%the same file.

clc
clear variables

filename = 'recording.bin'; %Input filename of the recording here
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
if (feof(fid)) %for some reason the feof in while loop doesn't trigger until fread fails when attempting to read start of next frame packet header
    break;
end
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
timeStamp = uint64(fread(fid,1,'int64'));
normalization_offset = fread(fid,1,'float');
normalization_nfactor = fread(fid,1,'float');
filter_normalization_factor = fread(fid,1,'float');

garbage = fread(fid,1,'uint32'); %Because size of header is 248 bytes

data = uint32(fread(fid,(bytes/4),'uint32'));
data_string = "";
if ((~isempty(find(data == 167,1)))||(~isempty(find(data == 16843009,1))))
    disp('Found a suspicious data point!');
end
% for i=1:length(data)
%     data_string = strcat(data_string,",",num2str(data(i)));
% end
framePackets = framePackets +1;
end
frewind(fid)
fclose(fid);
disp(['Successfully read ' num2str(framePackets*50) ' frames']);