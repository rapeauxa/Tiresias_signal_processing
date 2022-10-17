clc
clear
close all

%% Huffman coding parameters

% Load SH codewords
CW_file = "stored_SH_461.txt";
% Load Bin values
bins_file = "stored_bins_461.txt";

[values,dictMtx,minLen] = Huffman_init(CW_file,bins_file);

%% read data from data base

conn = sqlite('buffer.db');
tablename = "DATAFRAME";
results = sqlread(conn,tablename);
close(conn)

%% Convert Radar data to packages

radar_data = results.data;
package_num = length(radar_data);
compressed_data_uint32 = cell(package_num,1);

for ipackage = 1:package_num

    uint8_place_holder = matlab.net.base64decode(radar_data(ipackage));
    compressed_data_uint32{ipackage,:} = typecast(uint8_place_holder,'uint32');

end

%% Huffman decoder

% select the fixed length to save time
% decoded_length = 16700;
% decoded_data = zeros(decoded_length,length(radar_data));
decoded_data = cell(package_num,1);

f = waitbar(0,'Please wait...');
time1 = tic;


for ipackage = 1:package_num

    datapackage = compressed_data_uint32{ipackage,:};

    codeword_total = zeros(32*length(datapackage),1);
%     tic
    for jframe = 1:length(datapackage)
        % Time saving method of converting binstr to bin array
        codeword = (dec2bin(datapackage(jframe),32)) =='1';
        codeword_total(1+(jframe-1)*32:jframe*32) = codeword;
    end
    %     toc
    % Huffman decoder -- modified version
    % takes 0.2 second to decode one package of radar data
    decoded_data{ipackage} =  Huffman_decoder(codeword_total,dictMtx,values,minLen);
    %     TEMP = Huffman_decoder(codeword_total,dictMtx,values,minLen);
    %     decoded_data(:,ipackage) = TEMP(1:decoded_length);
%     toc
    if (~mod(ipackage,2))
        waitbar(ipackage/package_num,f,'Processing...');
        timeElapsed = toc(time1);
        disp('ETA ')
        disp((package_num-ipackage)/(ipackage/timeElapsed))
    end
end

%% Packages to frames

% The length of each package is slightly different, use the fixed value
bin_length = 16700/50;
frame_holder = zeros(package_num*50,bin_length);

for iframe = 1:package_num
    temp = decoded_data{iframe};
    for jframe = 1:50
        frame_holder((iframe-1)*50 + jframe,:) = temp((jframe-1)*bin_length+1:jframe*bin_length);
    end
end

%% save data

data_length_1 = size(frame_holder,2);

i_vec_1 = frame_holder(:,1:data_length_1/2);
q_vec_1 = frame_holder(:,data_length_1/2+1:data_length_1);

raw_data = i_vec_1 + 1i*q_vec_1;

save('test.mat',"raw_data");
