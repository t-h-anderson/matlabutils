function uid = uniqueID(varargin)
arguments (Repeating)
    varargin
end
uid = matlab.lang.internal.uuid(varargin{:});
end