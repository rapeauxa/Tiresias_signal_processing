function [values,dictMtx,minLen] = Huffman_init(CW_file,bins_file)

% Huffman_init generate the Huffman code book baesd on the SH codewords and
% bin values
% "stored_SH_461.txt" and "stored_bins_461.txt" shoud be in the 

% Load SH codewords
% CW_file = "stored_SH_461.txt";
CW_file_ID = fopen(CW_file,"r");

SH_codewords = textscan(CW_file_ID,'%s','Delimiter','\n');
SH_codewords = SH_codewords{1};

fclose(CW_file_ID);

% Load Bin values
% bins_file = "stored_bins_461.txt";
bins_file_ID = fopen(bins_file,"r");

values = textscan(bins_file_ID,'%s','Delimiter',',');
values = str2double(values{1});

fclose(bins_file_ID);

% Generate Huffman dictionary
dict = cell(length(SH_codewords),2);
for iCW = 1:length(SH_codewords)

    dict{iCW,1} = values(iCW);
    dict{iCW,2} = str2array(SH_codewords{iCW});

end

%
% values = str2double(values);
% Format codewords into a matrix
codewordLen = cellfun(@length, dict(:,2));
maxLen = max(codewordLen);
minLen = min(codewordLen);
dictMtx = cell2mat(cellfun(@(x)[x, -1*ones(1, maxLen-length(x))], ...
    dict(:,2), 'UniformOutput', false));

end

