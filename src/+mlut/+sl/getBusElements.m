function busElements = getBusElements(busName, nvp)
%GETBUSELEMENTS Element metadata for a Simulink bus definition.

arguments
    busName (1,1) string
    nvp.DataDictionary Simulink.data.Dictionary {mustBeScalarOrEmpty} = Simulink.data.Dictionary.empty(1,0)
    nvp.DataDictionaryName (1,1) string = string(NaN)
    nvp.ModelName (1,1) string = string(NaN)
    nvp.ModelFolder (1,1) string = ""
end

dictionaryCleanup = onCleanup.empty(1,0);
[dd, sourceDescription, dictionaryCleanup] = openDictionary(nvp, dictionaryCleanup); %#ok<ASGLU>
busObj = findBusObject(busName, dd);

if isempty(busObj)
    error("mlut:sl:getBusElements:busNotFound", ...
        "Bus '%s' was not found in the workspace or %s.", busName, sourceDescription);
end

busElements = extractElements(busObj, dd);
end

function [dd, sourceDescription, cleanupObj] = openDictionary(nvp, cleanupObj)
if ~isempty(nvp.DataDictionary)
    dd = nvp.DataDictionary;
    sourceDescription = "data dictionary object";
    return
end

if ~ismissing(nvp.DataDictionaryName)
    [dd, cleanupObj] = mlut.sl.DataDictionary.open(nvp.DataDictionaryName);
    sourceDescription = "data dictionary '" + nvp.DataDictionaryName + "'";
    return
end

if ~ismissing(nvp.ModelName)
    [dd, cleanupObj] = mlut.sl.DataDictionary.openForModel( ...
        nvp.ModelName, ModelFolder=nvp.ModelFolder);
    sourceDescription = "data dictionary for model '" + nvp.ModelName + "'";
    return
end

error("mlut:sl:getBusElements:dictionaryNotSpecified", ...
    "Supply DataDictionary, DataDictionaryName, or ModelName.")
end

function busObj = findBusObject(busName, dd)
busObj = [];
busName = erase(busName, "Bus:");
busName = strtrim(busName);

if ~isempty(dd)
    try
        designData = getSection(dd, "Design Data");
        entry = getEntry(designData, char(busName));
        value = getValue(entry);
        if isa(value, "Simulink.Bus")
            busObj = value;
            return
        end
    catch
        % Fall through to the base workspace lookup for legacy callers.
    end
end

try
    value = evalin("base", busName);
    if isa(value, "Simulink.Bus")
        busObj = value;
    end
catch
    % A missing base-workspace variable is represented by an empty result.
end
end

function elements = extractElements(busObj, dd)
elements = repmat( ...
    struct("Name", "", "DataType", "", "Dimensions", [], "IsBus", false, "Elements", struct([])), ...
    1, numel(busObj.Elements));

for i = 1:numel(busObj.Elements)
    elem = busObj.Elements(i);
    nestedBusObj = findBusObject(elem.DataType, dd);

    elements(i).Name = string(elem.Name);
    elements(i).DataType = string(elem.DataType);
    elements(i).Dimensions = elem.Dimensions;
    elements(i).IsBus = ~isempty(nestedBusObj);

    if elements(i).IsBus
        elements(i).Elements = extractElements(nestedBusObj, dd);
    end
end
end
