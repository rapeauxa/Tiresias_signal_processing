function [sdRead,format,frameNumber,bins,datalen,KFrameDataAddr,DFrameDataAddr,strLength,timeStamp,normalization_offset,normalization_nfactor,filter_normalization_factor,iData,qData] = sd_readframe(fid)

sdRead = fread(fid,1,'uint32');
format = fread(fid,1,'uint32');
frameNumber = fread(fid,1,'uint32');
bins = fread(fid,1,'int32');
datalen = fread(fid,1,'int32');
KFrameDataAddr = fread(fid,1,'int32');
DFrameDataAddr = fread(fid,49,'int32');
strLength = fread(fid,1,'int32');
timeStamp = fread(fid,1,'int64');
normalization_offset = fread(fid,1,'float');
normalization_nfactor = fread(fid,1,'float');
filter_normalization_factor = fread(fid,1,'float');
iData = zeros(50,bins);
qData = zeros(50,bins);
%Q data then i data
for i=1:50
    iData(i,:) = fread(fid,bins,'float'); %i data
    qData(i,:) = fread(fid,bins,'float'); %q data
end
sdRead = fread(fid,1,'uint32');



end