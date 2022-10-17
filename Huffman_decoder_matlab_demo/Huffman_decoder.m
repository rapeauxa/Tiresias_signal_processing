function [deco] = Huffman_decoder(comp,dictMtx,values,minLen)
%HUFFMANDECO Decode an input signal using a Huffman dictionary
%    

% Initialize output symbol indices to the worst length
symIdx = zeros(1, round(length(comp)/minLen)); 

% Initialize searching indices
numSym = size(dictMtx, 1);
parentIdx = 1:numSym;
dictIdx = 1;
symCounter = 0;

for i = 1:length(comp)
    % Update indices of codewords that match the current bit
    parentIdx = parentIdx(comp(i) == dictMtx(parentIdx, dictIdx));
    coder.internal.errorIf(isempty(parentIdx), ...
        'comm:huffmandeco:CodeNotFound');
    if isscalar(parentIdx) % Find a matching codeword
        % Log codeword/symbol index
        symCounter = symCounter + 1;
        symIdx(symCounter) = parentIdx;
        % Reset searching indices
        parentIdx = 1:numSym;
        dictIdx = 1;
    else % Update searching indices
        dictIdx = dictIdx + 1;
    end
end

% Output symbols from dictionary
deco = values(symIdx(1:symCounter));
% if all(cellfun(@(x)isnumeric(x)&&isscalar(x), dict(:,1)))
%     deco = ([deco{:}]).';
% end

% Transpose column output for a row input
if isrow(comp)  
    deco = deco.';  
end

end
