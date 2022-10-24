function array = str2array(char)

    array = zeros(size(char));
    for i = 1:length(char)
        array(i) = str2double(char(i));
    end

end
