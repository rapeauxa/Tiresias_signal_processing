clc
clear
close all

% if you want to plot all the figure
debug = 1;
%% load Radar data
% raw data matrix
load("radar_test.mat")

%% Generate range vector
[frames, bins] = size(raw_data);
c=physconst('LightSpeed'); %Speed of light in m/s.
% Generate range vector
bin_length =  8 * (c/2)/23.328e9; % range_decimation_factor * (c/2) / fs.
range_vector = 0.18:bin_length:0.18+bin_length*(bins-1);

%% Average every 20 frame and remove the direct Tx to Rx problem

fps_div = 20;
avg_num = floor(frames/fps_div);
fps = 500/fps_div;

removed_bin_num = 2;
IQ_data = zeros(avg_num, bins-removed_bin_num+1);

for iavg = 1:avg_num
    temp = mean( raw_data( (iavg-1)*fps_div+1:iavg*fps_div , removed_bin_num:end ) );
    IQ_data(iavg,:) = temp;
end

range_vector = range_vector(removed_bin_num:end);
frame_vector = 0:1/fps:(avg_num-1)/fps;

%% Remove first and last 20s as it may contain some noise

removed_bin_num = 20*fps;
IQ_data = IQ_data(removed_bin_num:end-removed_bin_num,:);
frame_vector = frame_vector(removed_bin_num:end-removed_bin_num);

%% clutter removal
% detrend_data = IQ_data - mean(IQ_data);
detrend_data = detrend(IQ_data);
% b = fir1(25,[0.01 0.1],'scale');
% data_clowpassed = filtfilt(b,1,detrend_data);
detrend_data_abs = detrend(abs(IQ_data));

figure
surf(range_vector,frame_vector,detrend(abs(IQ_data)));
shading interp
axis tight
c = colorbar('TickLabelInterpreter',"latex");
c.Label.String = 'Power(dB)';
title({'Range Profile: detrend signal' ; 'Normal breathing in Radar data'});
ylabel('Time (s)');
xlabel('Range (m)');
colormap(jet)

%% Position estimation

% select the bin with the maximum var. It can also be determined more accurately
% by calculating the values of kurtosis and variance, but for objects that do not
% move, variance is sufficient.
[~,position_index] = max(var(detrend(abs(IQ_data))));

%% EEMD algorithm for breathing signal extraction

% breathing frequency range
breathing_frange = [0.1 1.5];
% bandpass filter design
fcut = breathing_frange/fps;
b = fir1(25,fcut,'scale');
% range bins
subject_range = (position_index-round(0.05/bin_length)):(position_index+round(0.05/bin_length));
abs_bin = sum(detrend_data_abs(:,subject_range),2);
% filter the signal
abs_bin = filtfilt(b,1,abs_bin);
% EEMD
modes = eemd(abs_bin,0.1,10,100);
% select the IMF with the maximum energy since all the clutters are removed
[~,loc] = max(sum(abs(modes),2));
EEMD_output = modes(loc,:);
% frequcency estimation
fftmax = fftmax_with_boundarise(EEMD_output,fps,breathing_frange);
% display the result
disp(['EEMD Estimated Respiratory is:  ' num2str(round(fftmax*60)),'/min']);

%% Plot all the IMFs for debuging

if debug

    [imf_num, signal_len]=size(modes);
    figure_nun = imf_num + 1;

    figure
    subplot(figure_nun,1,1);
    plot(abs_bin);title('Radar Raw')

    for ifigure=2:figure_nun
        subplot(figure_nun,1,ifigure);
        plot(modes(ifigure-1,:),'LineWidth',1.5);
        if ifigure == loc
            title ( ['IMF ' num2str(ifigure-1) 'Respiratory signal extracted by algorithm'] );
        else
            title ( ['IMF ' num2str(ifigure-1)] );
        end
        
        xlim([1 signal_len])
    end
end

%% EEMD algorithm for Respiratory and heartbeat joint detection

% fft num; increase the num for zero padding
f_num_STFT = 1000;
fs = 23.328e9; %fps
f_STFT = (-fs/2):fs/f_num_STFT: (fs/2) - (fs/f_num_STFT);
% fft along fast time axis at dc
[~,index_zero] = min(abs(f_STFT - 0));

% phase information 
for iframe = 1:size(IQ_data,1)

    fft_result = fftshift(fft(detrend_data(iframe,:),f_num_STFT));
    [~,index_fmax] = max(abs(fft_result));

    phase_zero(iframe) = angle(fft_result(index_zero));
    phase_pos(iframe) = angle(detrend_data(iframe,position_index));

end
% raw abs data
raw_rangebin = normalize(detrend(abs(IQ_data(:,position_index))));

% plot the phase data
figure
plot(frame_vector, phase_zero,'LineWidth',1.5)
title('phase information calculated from complex data')
xlim([frame_vector(1) frame_vector(end)])
hold on
plot(frame_vector, phase_pos,'LineWidth',1.5)
plot(frame_vector, raw_rangebin,'LineWidth',1.5)
legend('fft at dc','direct angle','raw data')

% MEMD 
memd_input=[phase_zero' phase_pos' raw_rangebin]; % concatenate the input signals x and y with the additional WGN channels
IMF=memd(memd_input);

% maximum energy IMF belongs to breathing
IMF_energy = sum(sum(abs(IMF),1),3);
[~,max_loc] = max(IMF_energy);
MEMD_out_respiratory = mean(IMF(:,max_loc,:),1);
% frequcency estimation
fftmax = fftmax_with_boundarise(MEMD_out_respiratory(:)',fps,breathing_frange);
% display the result
disp(['MEMD Estimated Respiratory is: ' num2str(round(fftmax*60)),'/min']);

% Haven't have an idea how to choose the heartbeat IMF
% use the second large energy for now
IMF_energy(max_loc) = 0;
[~,max_loc_2]=max(IMF_energy);
MEMD_out_heartbeat = mean(IMF(:,max_loc_2,:),1);
% frequcency estimation
fftmax = fftmax_with_boundarise(MEMD_out_heartbeat(:)',fps,[0.7 2]);
% display the result
disp(['MEMD Estimated heartrate is: ' num2str(round(fftmax*60)),'/min']);

%% display all the IMFs for testing
[col, row, datasize] = size(IMF);
temp = zeros(datasize,1);
if debug
figure
title('All IMFs for MEMD out put for debuging')
for i= 1:col
    for j = 1:row

        subplot(row,col,i+(j-1)*col)
        temp = IMF(i,j,:);
        temp = temp(:);
        plot(frame_vector,temp,'LineWidth',2)
        xlim([frame_vector(1) frame_vector(end)])

        FFT_signal = (fft(temp.* hann(length(temp))));
        windowLength = length(temp);
        %Frequency vector for FFT with same number of elements as FFT itself
        fftFreqs = (0:(windowLength-1))*fps/windowLength;
        fftFreqs(fftFreqs >= fps/2) = fftFreqs(fftFreqs >= fps/2) -fps;

        [~,freqMax] = max(abs(FFT_signal));
        heartbeat = fftFreqs(freqMax) * 60;
        title(['The frequency calculated is:' num2str(heartbeat) 'beats/min and ' num2str(heartbeat/60) 'Hz'])
    end
end

end

%% Plot the final result: compare two different method on respiratory signal

figure

subplot(4,1,1)
plot(frame_vector, normalize(detrend_data_abs(:,position_index),"range"),'LineWidth',2)
title('Raw detrand radar signal')
xlim([frame_vector(1) frame_vector(end)])

subplot(4,1,2)
plot(frame_vector,normalize(EEMD_output,'range'),'LineWidth',2)
title('Respiratory signal extracted by EEMD')
xlim([frame_vector(1) frame_vector(end)])

subplot(4,1,3)
plot(frame_vector,normalize(MEMD_out_respiratory(:),'range'),'LineWidth',2)
title('Respiratory signal extracted by MEMD')
xlim([frame_vector(1) frame_vector(end)])

subplot(4,1,4)
plot(frame_vector, normalize(detrend_data_abs(:,position_index),"range"),'LineWidth',2)
title('Three in one figure')
xlim([frame_vector(1) frame_vector(end)])
hold on
plot(frame_vector,normalize(EEMD_output,'range'),'LineWidth',2)
plot(frame_vector,normalize(MEMD_out_respiratory(:),'range'),'LineWidth',2)
legend('raw radar data','Respiratory signal extracted by EEMD','Respiratory signal extracted by MEMD')

%% 
