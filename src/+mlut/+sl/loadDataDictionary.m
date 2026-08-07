function [dd, co] = loadDataDictionary(ddPath)
%LOADDATADICTIONARY Open a Simulink data dictionary by path or name.

arguments
    ddPath (1,1) string
end
[~, ddName, ext] = fileparts(ddPath);
if isempty(ext) || ext == ""
    ext = ".sldd";
end
ddFile = ddName + ext;

try
    % Check if dictionary is already open
    openDicts = Simulink.data.dictionary.getOpenDictionaryPaths();
    wasOpen = any(cellfun(@(x) endsWith(x, ddFile), openDicts));

    % Open the data dictionary (or get reference if already open)
    dd = Simulink.data.dictionary.open(ddFile);

    % Only create cleanup object if we opened it (wasn't already open)
    if ~wasOpen && nargout > 1
        co = onCleanup(@()dd.close());
    else
        co = [];
    end

catch me
    error("mlut:sl:loadDataDictionary:OpenFailed", ...
        "Failed to open data dictionary %s. %s", ddPath, me.message);
end
end
