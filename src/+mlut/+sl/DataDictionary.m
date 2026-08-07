classdef DataDictionary < mlut.internal.CacheSingleton
    %DATADICTIONARY Simulink data dictionary lifecycle and content utilities.

    properties (Access = private)
        RefCounts
        OpenedByManager
        Objects
        EntryCacheCreatedAt
        EntryCache
        BusCacheCreatedAt
        BusCache
        PathKeyCacheCreatedAt
        PathKeyCache
    end

    methods (Access = private)
        function obj = DataDictionary()
            obj.clearTrackingImpl();
            obj.clearCacheImpl();
        end

        function [dictObj, cleanupObj] = openImpl(obj, dictName, nvp)
            arguments
                obj (1,1) mlut.sl.DataDictionary
                dictName (1,1) string
                nvp.Optional (1,1) logical = false
            end

            cleanupObj = onCleanup.empty(1,0);
            if dictName == ""
                if nvp.Optional
                    dictObj = Simulink.data.Dictionary.empty(1,0);
                    return
                end
                error("mlut:sl:dataDictionaryMissing", ...
                    "A data dictionary name is required.")
            end

            try
                openBefore = obj.currentImpl();
                dictObj = Simulink.data.dictionary.open(char(dictName));
                openAfter = obj.currentImpl();
            catch me
                if nvp.Optional
                    dictObj = Simulink.data.Dictionary.empty(1,0);
                    return
                end
                error("mlut:sl:dataDictionaryOpenFailed", ...
                    "Unable to open data dictionary '%s': %s", dictName, me.message)
            end

            newPaths = openAfter(~ismember(openAfter, openBefore));
            openedByManager = ~isempty(newPaths);
            dictKey = resolveKey(dictName, openAfter, newPaths);

            obj.track(dictKey, openedByManager, dictObj);
            if nargout > 1
                cleanupObj = onCleanup(@() obj.release(dictKey));
            end
        end

        function [dictObj, cleanupObj] = openForModelImpl(obj, modelName, nvp)
            arguments
                obj (1,1) mlut.sl.DataDictionary
                modelName (1,1) string
                nvp.ModelFolder (1,1) string = ""
                nvp.AllowNoDictionary (1,1) logical = false
                nvp.Optional (1,1) logical = false
            end

            cleanupObj = onCleanup.empty(1,0);
            [dictPath, dictName] = dictionaryPathForModel(modelName, nvp.ModelFolder);
            if dictName == ""
                if nvp.AllowNoDictionary || nvp.Optional
                    dictObj = Simulink.data.Dictionary.empty(1,0);
                    return
                end
                error("mlut:sl:dataDictionaryMissing", ...
                    "Model '%s' does not specify a data dictionary.", modelName)
            end

            if nargout > 1
                [dictObj, cleanupObj] = obj.openImpl(dictPath, Optional=nvp.Optional);
            else
                dictObj = obj.openImpl(dictPath, Optional=nvp.Optional);
            end
        end

        function closeImpl(obj, dictName)
            arguments
                obj (1,1) mlut.sl.DataDictionary
                dictName (1,1) string
            end

            openPaths = obj.currentImpl();
            newPaths = string.empty(1,0);
            dictKey = resolveKey(dictName, openPaths, newPaths);
            closeNoSave(dictKey);
            obj.remove(dictKey);
        end

        function dictPaths = managedImpl(obj)
            arguments
                obj (1,1) mlut.sl.DataDictionary
            end

            dictPaths = string(keys(obj.RefCounts));
            dictPaths = reshape(dictPaths, 1, []);
        end

        function dictPaths = currentImpl(obj)
            matlabOpenPaths = mlut.sl.DataDictionary.openPaths();
            managedOpenPaths = obj.openManaged();
            allOpenPaths = [matlabOpenPaths, managedOpenPaths];
            dictPaths = unique(allOpenPaths, "stable");
        end

        function clearTrackingImpl(obj)
            obj.RefCounts = dictionary(string.empty(1,0), double.empty(1,0));
            obj.OpenedByManager = dictionary(string.empty(1,0), logical.empty(1,0));
            obj.Objects = dictionary(string.empty(1,0), cell.empty(1,0));
        end

        function clearCacheImpl(obj)
            obj.EntryCacheCreatedAt = datetime.empty(1,0);
            obj.EntryCache = dictionary();
            obj.BusCacheCreatedAt = datetime.empty(1,0);
            obj.BusCache = dictionary();
            obj.PathKeyCacheCreatedAt = datetime.empty(1,0);
            obj.PathKeyCache = dictionary(string.empty(1,0), string.empty(1,0));
        end

        function expireEntriesIfNeeded(obj)
            if obj.cacheExpired(obj.EntryCacheCreatedAt)
                obj.EntryCache = dictionary();
                obj.EntryCacheCreatedAt = datetime("now");
            end
        end

        function expireBusIfNeeded(obj)
            if obj.cacheExpired(obj.BusCacheCreatedAt)
                obj.BusCache = dictionary();
                obj.BusCacheCreatedAt = datetime("now");
            end
        end

        function expirePathKeysIfNeeded(obj)
            if obj.cacheExpired(obj.PathKeyCacheCreatedAt)
                obj.PathKeyCache = dictionary(string.empty(1,0), string.empty(1,0));
                obj.PathKeyCacheCreatedAt = datetime("now");
            end
        end

        function track(obj, dictKey, openedByManager, dictObj)
            if isKey(obj.RefCounts, dictKey)
                obj.RefCounts(dictKey) = obj.RefCounts(dictKey) + 1;
                obj.OpenedByManager(dictKey) = obj.OpenedByManager(dictKey) || openedByManager;
                obj.Objects(dictKey) = {dictObj};
                return
            end

            obj.RefCounts(dictKey) = 1;
            obj.OpenedByManager(dictKey) = openedByManager;
            obj.Objects(dictKey) = {dictObj};
        end

        function release(obj, dictKey)
            if ~isKey(obj.RefCounts, dictKey)
                return
            end

            remainingCount = obj.RefCounts(dictKey) - 1;
            if remainingCount > 0
                obj.RefCounts(dictKey) = remainingCount;
                return
            end

            openedByManager = obj.OpenedByManager(dictKey);
            obj.remove(dictKey);
            if openedByManager
                closeNoSave(dictKey);
            end
        end

        function remove(obj, dictKey)
            if isKey(obj.RefCounts, dictKey)
                obj.RefCounts = remove(obj.RefCounts, dictKey);
            end
            if isKey(obj.OpenedByManager, dictKey)
                obj.OpenedByManager = remove(obj.OpenedByManager, dictKey);
            end
            if isKey(obj.Objects, dictKey)
                obj.Objects = remove(obj.Objects, dictKey);
            end
        end

        function dictPaths = openManaged(obj)
            managedPaths = obj.managedImpl();
            isOpen = false(1, numel(managedPaths));
            for i = 1:numel(managedPaths)
                dictCell = obj.Objects(managedPaths(i));
                dictObj = dictCell{1};
                isOpen(i) = dictObj.isOpen();
            end
            dictPaths = managedPaths(isOpen);
        end

        function entries = findEntriesImpl(obj, dictName, searchTerms, optional)
            entryKey = obj.keyForPathImpl(dictName) + "|" + strjoin(searchTerms, "|");
            [entries, found] = obj.cachedEntries(entryKey);
            if found
                return
            end

            [designData, cleanupObj] = mlut.sl.DataDictionary.designData( ...
                dictName, Optional=optional); %#ok<ASGLU>
            if isempty(designData)
                entries = struct("Name", {}, "Value", {});
                obj.setCachedEntries(entryKey, entries);
                return
            end

            searchCell = num2cell(searchTerms);
            foundEntries = designData.find(searchCell{:});
            nEntries = numel(foundEntries);
            entries = repmat(struct("Name", "", "Value", []), 1, nEntries);
            for i = 1:nEntries
                entry = foundEntries(i);
                entries(i).Name = string(entry.Name);
                entries(i).Value = getValue(entry);
            end
            obj.setCachedEntries(entryKey, entries);
        end

        function busObj = busObjectImpl(obj, dictName, itemName, optional)
            busName = mlut.sl.Bus.objectName(itemName);
            if busName == ""
                busName = strip(itemName);
            end
            busKey = obj.keyForPathImpl(dictName) + "|" + busName;
            [busObj, found] = obj.cachedBusObject(busKey);
            if found
                return
            end

            [designData, cleanupObj] = mlut.sl.DataDictionary.designData( ...
                dictName, Optional=optional); %#ok<ASGLU>
            if isempty(designData)
                busObj = Simulink.Bus.empty(1,0);
                obj.setCachedBusObject(busKey, busObj);
                return
            end

            try
                entry = getEntry(designData, char(busName));
                busObj = getValue(entry);
            catch me
                if optional
                    busObj = Simulink.Bus.empty(1,0);
                    obj.setCachedBusObject(busKey, busObj);
                    return
                end
                error("mlut:sl:busObjectNotFound", ...
                    "Bus object '%s' was not found in data dictionary '%s': %s", ...
                    busName, dictName, me.message);
            end

            if ~isa(busObj, "Simulink.Bus")
                if optional
                    busObj = Simulink.Bus.empty(1,0);
                else
                    error("mlut:sl:entryIsNotBusObject", ...
                        "Entry '%s' in data dictionary '%s' is not a Simulink.Bus.", ...
                        busName, dictName);
                end
            end
            obj.setCachedBusObject(busKey, busObj);
        end

        function [entries, found] = cachedEntries(obj, key)
            obj.expireEntriesIfNeeded();
            entries = struct("Name", {}, "Value", {});
            found = false;
            if obj.EntryCache.isConfigured && isKey(obj.EntryCache, key)
                cached = obj.EntryCache(key);
                entries = cached{1};
                found = true;
            end
        end

        function setCachedEntries(obj, key, entries)
            obj.expireEntriesIfNeeded();
            obj.EntryCache(key) = {entries};
        end

        function [busObj, found] = cachedBusObject(obj, key)
            obj.expireBusIfNeeded();
            busObj = [];
            found = false;
            if obj.BusCache.isConfigured && isKey(obj.BusCache, key)
                cached = obj.BusCache(key);
                busObj = cached{1};
                found = true;
            end
        end

        function setCachedBusObject(obj, key, busObj)
            obj.expireBusIfNeeded();
            obj.BusCache(key) = {busObj};
        end

        function key = keyForPathImpl(obj, dictName)
            obj.expirePathKeysIfNeeded();
            isDirectFile = isfile(dictName);
            if isDirectFile
                lookupKey = "file|" + dictName;
            else
                lookupKey = "path|" + dictName;
            end

            if obj.PathKeyCache.isConfigured && isKey(obj.PathKeyCache, lookupKey)
                key = obj.PathKeyCache(lookupKey);
                return
            end

            if isDirectFile
                resolved = string(dictName);
            else
                resolved = string(which(dictName));
            end
            if resolved == ""
                resolved = dictName;
            end
            key = resolved;
            obj.PathKeyCache(lookupKey) = key;
        end
    end

    methods (Static)
        function [dictObj, cleanupObj] = open(dictName, nvp)
            arguments
                dictName (1,1) string
                nvp.Optional (1,1) logical = false
            end

            cleanupObj = onCleanup.empty(1,0);
            manager = mlut.sl.DataDictionary.make();
            if nargout > 1
                [dictObj, cleanupObj] = manager.openImpl(dictName, Optional=nvp.Optional);
            else
                dictObj = manager.openImpl(dictName, Optional=nvp.Optional);
            end
        end

        function [dictObj, cleanupObj] = openForModel(modelName, nvp)
            arguments
                modelName (1,1) string
                nvp.ModelFolder (1,1) string = ""
                nvp.AllowNoDictionary (1,1) logical = false
                nvp.Optional (1,1) logical = false
            end

            cleanupObj = onCleanup.empty(1,0);
            manager = mlut.sl.DataDictionary.make();
            if nargout > 1
                [dictObj, cleanupObj] = manager.openForModelImpl( ...
                    modelName, ...
                    ModelFolder=nvp.ModelFolder, ...
                    AllowNoDictionary=nvp.AllowNoDictionary, ...
                    Optional=nvp.Optional);
            else
                dictObj = manager.openForModelImpl( ...
                    modelName, ...
                    ModelFolder=nvp.ModelFolder, ...
                    AllowNoDictionary=nvp.AllowNoDictionary, ...
                    Optional=nvp.Optional);
            end
        end

        function dictName = nameForModel(modelName)
            arguments
                modelName (1,1) string
            end

            [~, dictName] = dictionaryPathForModel(modelName, "");
        end

        function dictPath = pathForModel(modelName, nvp)
            arguments
                modelName (1,1) string
                nvp.ModelFolder (1,1) string = ""
            end

            dictPath = dictionaryPathForModel(modelName, nvp.ModelFolder);
        end

        function [designData, cleanupObj] = designData(dictName, nvp)
            arguments
                dictName (1,1) string
                nvp.Optional (1,1) logical = false
                nvp.Cleanup (1,:) onCleanup = onCleanup.empty(1,0)
            end

            if nargout > 1
                [designData, cleanupObj] = loadDesignData(dictName, nvp.Optional, nvp.Cleanup);
            else
                designData = loadDesignData(dictName, nvp.Optional);
            end
        end

        function [designData, cleanupObj] = designDataForModel(modelName, nvp)
            arguments
                modelName (1,1) string
                nvp.ModelFolder (1,1) string = ""
                nvp.AllowNoDictionary (1,1) logical = false
                nvp.Optional (1,1) logical = false
                nvp.Cleanup (1,:) onCleanup = onCleanup.empty(1,0)
            end

            cleanupObj = nvp.Cleanup;
            [dictPath, dictName] = dictionaryPathForModel(modelName, nvp.ModelFolder);
            if dictName == ""
                if nvp.AllowNoDictionary || nvp.Optional
                    designData = Simulink.data.dictionary.Section.empty(1,0);
                    return
                end
                error("mlut:sl:dataDictionaryMissing", ...
                    "Model '%s' does not specify a data dictionary.", modelName);
            end

            if nargout > 1
                [designData, cleanupObj] = mlut.sl.DataDictionary.designData( ...
                    dictPath, Optional=nvp.Optional, Cleanup=cleanupObj);
            else
                designData = mlut.sl.DataDictionary.designData(dictPath, Optional=nvp.Optional);
            end
        end

        function entries = findEntries(dictName, searchTerms, nvp)
            arguments
                dictName (1,1) string
                searchTerms (1,:) string
                nvp.Filter (1,1) string = string(NaN)
                nvp.Optional (1,1) logical = false
            end

            manager = mlut.sl.DataDictionary.make();
            entries = manager.findEntriesImpl(dictName, searchTerms, nvp.Optional);
            if ~ismissing(nvp.Filter)
                entries = entries(arrayfun(@(entry) isa(entry.Value, nvp.Filter), entries));
            end
        end

        function busObj = busObject(dictName, itemName, nvp)
            arguments
                dictName (1,1) string
                itemName (1,1) string
                nvp.Optional (1,1) logical = false
            end

            manager = mlut.sl.DataDictionary.make();
            busObj = manager.busObjectImpl(dictName, itemName, nvp.Optional);
        end

        function busObj = busObjectForModel(modelName, itemName, nvp)
            arguments
                modelName (1,1) string
                itemName (1,1) string
                nvp.ModelFolder (1,1) string = ""
                nvp.Optional (1,1) logical = false
            end

            [dictPath, dictName] = dictionaryPathForModel(modelName, nvp.ModelFolder);
            if dictName == ""
                if nvp.Optional
                    busObj = Simulink.Bus.empty(1,0);
                    return
                end
                error("mlut:sl:dataDictionaryMissing", ...
                    "Model '%s' does not specify a data dictionary.", modelName);
            end

            busObj = mlut.sl.DataDictionary.busObject( ...
                dictPath, itemName, Optional=nvp.Optional);
        end

        function close(dictName)
            arguments
                dictName (1,1) string
            end

            manager = mlut.sl.DataDictionary.make();
            manager.closeImpl(dictName);
        end

        function dictPaths = managed()
            manager = mlut.sl.DataDictionary.make();
            dictPaths = manager.managedImpl();
        end

        function dictPaths = current()
            manager = mlut.sl.DataDictionary.make();
            dictPaths = manager.currentImpl();
        end

        function clearTracking()
            manager = mlut.sl.DataDictionary.make();
            manager.clearTrackingImpl();
            manager.clearCacheImpl();
        end

        function dictPaths = openPaths()
            dictPaths = string(Simulink.data.dictionary.getOpenDictionaryPaths());
            dictPaths = reshape(dictPaths, 1, []);
        end
    end

    methods (Static)
        function manager = make(reset)
            arguments
                reset (1,1) logical = false
            end

            factory = @() mlut.sl.DataDictionary();
            manager = mlut.internal.Singleton.instanceFor( ...
                "mlut.sl.DataDictionary", reset, factory, nargout > 0);
        end
    end
end

function [designData, cleanupObj] = loadDesignData(dictName, optional, cleanupObj)
if nargin < 3
    cleanupObj = onCleanup.empty(1,0);
end
if nargout > 1
    [dictObj, newCleanupObj] = mlut.sl.DataDictionary.open(dictName, Optional=optional);
    if ~isempty(newCleanupObj)
        cleanupObj = [cleanupObj, newCleanupObj];
    end
else
    dictObj = mlut.sl.DataDictionary.open(dictName, Optional=optional);
end
if isempty(dictObj)
    designData = Simulink.data.dictionary.Section.empty(1,0);
    return
end

try
    designData = getSection(dictObj, "Design Data");
catch me
    if optional
        designData = Simulink.data.dictionary.Section.empty(1,0);
        return
    end
    error("mlut:sl:designDataNotFound", ...
        "Data dictionary '%s' does not contain a Design Data section: %s", ...
        dictName, me.message);
end
end

function [dictPath, dictName] = dictionaryPathForModel(modelName, modelFolder)
arguments
    modelName (1,1) string
    modelFolder (1,1) string
end

modelTarget = modelTargetForFolder(modelName, modelFolder);
if modelFolder ~= "" && ~bdIsLoaded(mlut.sl.Model.nameFromInput(modelName)) ...
        && isfile(modelTarget)
    [dictName, found] = dictionaryNameFromModelFile(modelTarget);
    if found
        dictPath = dictName;
        if dictName ~= ""
            dictPath = resolveModelPath(dictName, modelFolder);
        end
        return
    end
end

[modelHandle, cleanupObj] = mlut.sl.Model.open(modelTarget); %#ok<ASGLU>
dictName = string(get_param(modelHandle, "DataDictionary"));
dictPath = dictName;
if dictName == ""
    return
end

if modelFolder == ""
    modelFile = string(get_param(modelHandle, "FileName"));
    if modelFile ~= ""
        modelFolder = string(fileparts(modelFile));
    end
end

dictPath = resolveModelPath(dictName, modelFolder);
end

function modelTarget = modelTargetForFolder(modelName, modelFolder)
arguments
    modelName (1,1) string
    modelFolder (1,1) string
end

modelTarget = modelName;
if modelFolder == "" ...
        || bdIsLoaded(mlut.sl.Model.nameFromInput(modelName)) ...
        || isfile(modelName)
    return
end

[~, modelBaseName, modelExt] = fileparts(modelName);
if modelExt ~= ""
    candidate = fullfile(modelFolder, modelBaseName + modelExt);
    if isfile(candidate)
        modelTarget = string(candidate);
    end
    return
end

for extension = [".slx", ".mdl"]
    candidate = fullfile(modelFolder, modelName + extension);
    if isfile(candidate)
        modelTarget = string(candidate);
        return
    end
end
end

function dictKey = resolveKey(dictName, openPaths, newPaths)
if ~isempty(newPaths)
    dictKey = newPaths(1);
    return
end

candidate = resolvePath(dictName);
if candidate ~= ""
    normalOpenPaths = normalisePath(openPaths);
    normalCandidate = normalisePath(candidate);
    matches = openPaths(normalOpenPaths == normalCandidate);
    if ~isempty(matches)
        dictKey = matches(1);
        return
    end
end

[~, dictFile, dictExt] = fileparts(dictName);
dictFileName = dictFile + dictExt;
for i = 1:numel(openPaths)
    [~, openFile, openExt] = fileparts(openPaths(i));
    if openFile + openExt == dictFileName
        dictKey = openPaths(i);
        return
    end
end

dictKey = dictName;
end

function dictPath = resolvePath(dictName)
dictPath = "";
if isfile(dictName)
    dictPath = dictName;
    return
end

resolved = string(which(dictName));
if resolved ~= ""
    dictPath = resolved;
end
end

function dictPath = resolveModelPath(dictName, modelFolder)
arguments
    dictName (1,1) string
    modelFolder (1,1) string
end

dictPath = dictName;
if isfile(dictPath)
    return
end

if modelFolder == ""
    return
end

candidate = fullfile(modelFolder, dictName);
if isfile(candidate)
    dictPath = string(candidate);
end
end

function [dictName, found] = dictionaryNameFromModelFile(modelPath)
dictName = "";
found = false;
[~, ~, ext] = fileparts(modelPath);
if lower(string(ext)) ~= ".slx"
    return
end

extractFolder = string(tempname);
mkdir(extractFolder);
cleanupFolder = onCleanup(@() removeTempFolder(extractFolder));
unzip(char(modelPath), char(extractFolder));

blockDiagramFile = fullfile(extractFolder, "simulink", "blockdiagram.xml");
if ~isfile(blockDiagramFile)
    return
end

xmlText = fileread(blockDiagramFile);
dictNames = extractXmlProperty(xmlText, "DataDictionary");
dictNames = dictNames(dictNames ~= "");
if ~isempty(dictNames)
    dictName = dictNames(1);
end
found = true;
end

function values = extractXmlProperty(xmlText, propertyName)
tokens = regexp(xmlText, ...
    "<P\s+Name=""" + propertyName + """>([^<]*)</P>", ...
    "tokens");
values = strings(1, numel(tokens));
for tokenIdx = 1:numel(tokens)
    values(tokenIdx) = decodeXmlText(tokens{tokenIdx}{1});
end
end

function text = decodeXmlText(text)
text = string(text);
text = replace(text, "&quot;", """");
text = replace(text, "&apos;", "'");
text = replace(text, "&lt;", "<");
text = replace(text, "&gt;", ">");
text = replace(text, "&amp;", "&");
end

function normalised = normalisePath(paths)
normalised = strings(size(paths));
for i = 1:numel(paths)
    [folder, name, ext] = fileparts(paths(i));
    normalised(i) = string(fullfile(folder, name + ext));
end
if ispc
    normalised = lower(normalised);
end
end

function closeNoSave(dictPath)
try
    Simulink.data.dictionary.closeAll(char(dictPath), "-discard");
catch
    [~, dictName, ext] = fileparts(dictPath);
    Simulink.data.dictionary.closeAll(char(dictName + ext), "-discard");
end
end

function removeTempFolder(folder)
if isfolder(folder)
    rmdir(folder, "s");
end
end
