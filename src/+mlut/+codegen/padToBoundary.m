function wordsOut = padToBoundary(wordsIn, padTo)
arguments
    wordsIn
    padTo (1,1) double {mustBeInteger, mustBePositive}
end

pad = mod(padTo - mod(numel(wordsIn), padTo), padTo);
wordsOut = [wordsIn, zeros(1, pad)];
end
