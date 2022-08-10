function [fftmax] = fftmax_with_boundarise(input,fs,boundarise)

% Add padding to increase the resolution
pad_factor = 10;
windowLength = length(input)*pad_factor;
FFT_signal = fft(input'.* hann(length(input)),windowLength);
% Zero padding, increase the frequency resolution
fftFreqs = (0:(windowLength-1))*fs/windowLength;
fftFreqs(fftFreqs >= fs/2) = fftFreqs(fftFreqs >= fs/2)-fs;
FFT_signal(fftFreqs<boundarise(1) | fftFreqs>boundarise(2)) = 0;

[~,freqMax] = max(abs(FFT_signal)); 
fftmax = fftFreqs(freqMax);

end

