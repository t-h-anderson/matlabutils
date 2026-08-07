classdef Model < mlut.internal.Singleton
    %MODEL Simulink model lifecycle and path utilities.

    properties (Access = private)
        RefCounts
        OpenedByManager
        Paths
    end

    methods (Access = private)
        function obj = Model()
            obj.clearTrackingImpl();
        end

        function [modelHandle, cleanupObj] = openImpl(obj, modelOrPath)
            arguments
                obj (1,1) mlut.sl.Model
                modelOrPath (1,1) string
            end

            cleanupObj = onCleanup.empty(1,0);
            [modelName, modelPath] = resolveModelTarget(modelOrPath);
            wasLoaded = bdIsLoaded(modelName);
            if wasLoaded
                modelHandle = get_param(modelName, "Handle");
            else
                try
                    modelHandle = loadSystemCleanly(modelName, modelPath);
                catch err
                    if bdIsLoaded(modelName)
                        close_system(modelName, 0);
                    end
                    rethrow(err);
                end
            end

            obj.track(modelName, ~wasLoaded, modelPath);
            if nargout > 1
                cleanupObj = onCleanup(@() obj.release(modelName));
            end
        end

        function closeImpl(obj, modelName, nvp)
            arguments
                obj (1,1) mlut.sl.Model
                modelName (1,1) string
                nvp.Save (1,1) logical = false
            end

            modelName = modelNameFromInput(modelName);
            if bdIsLoaded(modelName)
                close_system(modelName, nvp.Save);
            end
            obj.remove(modelName);
        end

        function models = managedModelsImpl(obj)
            arguments
                obj (1,1) mlut.sl.Model
            end

            models = string(keys(obj.RefCounts));
            models = reshape(models, 1, []);
        end

        function models = currentModelsImpl(~)
            models = mlut.sl.Model.openModels();
        end

        function clearTrackingImpl(obj)
            obj.RefCounts = dictionary(string.empty(1,0), double.empty(1,0));
            obj.OpenedByManager = dictionary(string.empty(1,0), logical.empty(1,0));
            obj.Paths = dictionary(string.empty(1,0), string.empty(1,0));
        end

        function track(obj, modelName, openedByManager, modelPath)
            if isKey(obj.RefCounts, modelName)
                obj.RefCounts(modelName) = obj.RefCounts(modelName) + 1;
                obj.OpenedByManager(modelName) = obj.OpenedByManager(modelName) || openedByManager;
                return
            end

            obj.RefCounts(modelName) = 1;
            obj.OpenedByManager(modelName) = openedByManager;
            obj.Paths(modelName) = modelPath;
        end

        function release(obj, modelName)
            if ~isKey(obj.RefCounts, modelName)
                return
            end

            remainingCount = obj.RefCounts(modelName) - 1;
            if remainingCount > 0
                obj.RefCounts(modelName) = remainingCount;
                return
            end

            openedByManager = obj.OpenedByManager(modelName);
            obj.remove(modelName);
            if openedByManager && bdIsLoaded(modelName)
                close_system(modelName, 0);
            end
        end

        function remove(obj, modelName)
            if isKey(obj.RefCounts, modelName)
                obj.RefCounts = remove(obj.RefCounts, modelName);
            end
            if isKey(obj.OpenedByManager, modelName)
                obj.OpenedByManager = remove(obj.OpenedByManager, modelName);
            end
            if isKey(obj.Paths, modelName)
                obj.Paths = remove(obj.Paths, modelName);
            end
        end
    end

    methods (Static)
        function [modelHandle, cleanupObj] = open(modelOrPath)
            arguments
                modelOrPath (1,1) string
            end

            cleanupObj = onCleanup.empty(1,0);
            manager = mlut.sl.Model.make();
            if nargout > 1
                [modelHandle, cleanupObj] = manager.openImpl(modelOrPath);
            else
                modelHandle = manager.openImpl(modelOrPath);
            end
        end

        function close(modelName, nvp)
            arguments
                modelName (1,1) string
                nvp.Save (1,1) logical = false
            end

            manager = mlut.sl.Model.make();
            manager.closeImpl(modelName, Save=nvp.Save);
        end

        function modelName = nameFromInput(modelOrPath)
            arguments
                modelOrPath (1,1) string
            end

            modelName = modelNameFromInput(modelOrPath);
        end

        function modelPath = resolvePath(modelName)
            arguments
                modelName (1,1) string
            end

            modelName = strip(modelName);
            modelPath = string(which(modelName));
            if modelPath == "" || ~isfile(modelPath)
                error("mlut:sl:modelNotOnPath", ...
                    "Model '%s' is not on the MATLAB path. Add its folder to the project path before tracing.", ...
                    modelName);
            end
        end

        function modelPath = requireOnPath(modelName)
            arguments
                modelName (1,1) string
            end

            modelPath = mlut.sl.Model.resolvePath(modelName);
        end

        function models = managedModels()
            manager = mlut.sl.Model.make();
            models = manager.managedModelsImpl();
        end

        function models = currentModels()
            manager = mlut.sl.Model.make();
            models = manager.currentModelsImpl();
        end

        function clearTracking()
            mlut.sl.Model.make(true);
        end

        function models = openModels()
            diagrams = Simulink.allBlockDiagrams();
            models = strings(1, numel(diagrams));
            for i = 1:numel(diagrams)
                modelName = get_param(diagrams(i), "Name");
                models(i) = string(modelName);
            end
        end
    end

    methods (Static)
        function manager = make(reset)
            arguments
                reset (1,1) logical = false
            end

            factory = @() mlut.sl.Model();
            manager = mlut.internal.Singleton.instanceFor( ...
                "mlut.sl.Model", reset, factory, nargout > 0);
        end
    end
end

function [modelName, modelPath] = resolveModelTarget(modelOrPath)
modelOrPath = strip(modelOrPath);
modelName = modelNameFromInput(modelOrPath);
if bdIsLoaded(modelName)
    modelPath = "";
    return
end

if isfile(modelOrPath)
    modelPath = modelOrPath;
    return
end

for ext = [".slx", ".mdl"]
    candidate = modelOrPath + ext;
    if isfile(candidate)
        modelPath = candidate;
        return
    end
end

modelPath = mlut.sl.Model.requireOnPath(modelName);
end

function modelHandle = loadSystemCleanly(modelName, modelPath)
preflightIssues = declaredLoadDependencyIssues(modelPath);
if ~isempty(preflightIssues)
    throwLoadDependencyError(modelName, modelPath, preflightIssues, "");
end

lastwarn("", "");
try
    modelHandle = load_system(char(modelPath));
    [warningMessage, warningId] = lastwarn();
    unresolvedDependencies = unresolvedLoadDependencies(modelName);
catch err
    error("mlut:sl:modelLoadFailed", ...
        "Unable to load model '%s': %s", modelPath, err.message);
end

if isLoadDependencyWarning(warningId) || ~isempty(unresolvedDependencies)
    throwLoadDependencyError( ...
        modelName, modelPath, unresolvedDependencies, warningMessage);
end

if warningMessage ~= ""
    reissueCapturedWarning(warningId, warningMessage);
end
end

function issues = declaredLoadDependencyIssues(modelPath)
[~, ~, ext] = fileparts(modelPath);
if lower(string(ext)) ~= ".slx"
    issues = strings(1, 0);
    return
end

extractFolder = string(tempname);
mkdir(extractFolder);
cleanupFolder = onCleanup(@() removeTempFolder(extractFolder));
unzip(char(modelPath), char(extractFolder));

issues = declaredDataDictionaryIssues(extractFolder);
issues = [issues, declaredModelReferenceIssues(extractFolder)];
issues = unique(issues, "stable");
end

function issues = declaredDataDictionaryIssues(extractFolder)
issues = strings(1, 0);
blockDiagramFile = fullfile(extractFolder, "simulink", "blockdiagram.xml");
if ~isfile(blockDiagramFile)
    return
end

xmlText = fileread(blockDiagramFile);
dictNames = extractXmlProperty(xmlText, "DataDictionary");
dictNames = dictNames(dictNames ~= "");
for dictIdx = 1:numel(dictNames)
    dictName = dictNames(dictIdx);
    if ~isFileResolvable(dictName)
        issues(end+1) = "data dictionary '" + dictName + "'"; %#ok<AGROW>
    end
end
end

function issues = declaredModelReferenceIssues(extractFolder)
issues = strings(1, 0);
systemsFolder = fullfile(extractFolder, "simulink", "systems");
if ~isfolder(systemsFolder)
    return
end

systemFiles = dir(fullfile(systemsFolder, "*.xml"));
for fileIdx = 1:numel(systemFiles)
    xmlText = fileread(fullfile(systemFiles(fileIdx).folder, systemFiles(fileIdx).name));
    blocks = regexp(xmlText, ...
        '(?s)<Block\s+[^>]*BlockType="ModelReference"[^>]*>.*?</Block>', ...
        "match");
    for blockIdx = 1:numel(blocks)
        refModels = extractXmlProperty(blocks{blockIdx}, "ModelNameDialog");
        refModels = refModels(refModels ~= "");
        if isempty(refModels)
            continue
        end
        refModel = refModels(1);
        if isModelReferenceResolvable(refModel)
            continue
        end
        blockName = extractXmlAttribute(blocks{blockIdx}, "Name");
        issues(end+1) = modelReferenceIssue(refModel, blockName); %#ok<AGROW>
    end
end
end

function tf = isLoadDependencyWarning(warningId)
warningId = string(warningId);
tf = warningId == "SLDD:sldd:DictionaryNotFound" ...
    || startsWith(warningId, "Simulink:modelReference:ModelNotFound");
end

function issues = unresolvedLoadDependencies(modelName)
issues = strings(1, 0);

dictName = string(get_param(char(modelName), "DataDictionary"));
if dictName ~= "" && ~isFileResolvable(dictName)
    issues(end+1) = "data dictionary '" + dictName + "'";
end

blocks = string(find_system(char(modelName), ...
    "LookUnderMasks", "all", ...
    "BlockType", "ModelReference"));
for blockIdx = 1:numel(blocks)
    refModel = string(get_param(char(blocks(blockIdx)), "ModelName"));
    if refModel == "" || isModelReferenceResolvable(refModel)
        continue
    end
    issues(end+1) = "referenced model '" + refModel + ...
        "' at '" + blocks(blockIdx) + "'"; %#ok<AGROW>
end

issues = unique(issues, "stable");
end

function tf = isFileResolvable(fileName)
tf = isfile(fileName) || string(which(fileName)) ~= "";
end

function tf = isModelReferenceResolvable(refModel)
modelName = modelNameFromInput(refModel);
tf = bdIsLoaded(modelName) || isfile(refModel) || string(which(refModel)) ~= "";
if tf
    return
end

for extension = [".slx", ".mdl"]
    if string(which(refModel + extension)) ~= ""
        tf = true;
        return
    end
end
end

function issue = modelReferenceIssue(refModel, blockName)
issue = "referenced model '" + refModel + "'";
if blockName ~= ""
    issue = issue + " (block '" + blockName + "')";
end
end

function details = dependencyDetails(issues, warningMessage)
if ~isempty(issues)
    details = newline + newline + "Unresolved dependencies:" + ...
        newline + "  - " + strjoin(issues, newline + "  - ");
    return
end

details = "";
if warningMessage ~= ""
    details = newline + newline + "Simulink warning: " + ...
        stripWarningMarkup(warningMessage);
end
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

function value = extractXmlAttribute(xmlText, attributeName)
tokens = regexp(xmlText, ...
    "\s" + attributeName + "=""([^""]*)""", ...
    "tokens", ...
    "once");
if isempty(tokens)
    value = "";
else
    value = decodeXmlText(tokens{1});
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

function message = stripWarningMarkup(message)
message = string(regexprep(message, "<[^>]*>", ""));
message = replace(message, newline, " ");
message = strip(message);
end

function reissueCapturedWarning(warningId, warningMessage)
warningId = string(warningId);
warningMessage = string(warningMessage);
if warningId == ""
    warning("%s", warningMessage);
else
    warning(warningId, "%s", warningMessage);
end
end

function throwLoadDependencyError(modelName, modelPath, issues, warningMessage)
details = dependencyDetails(issues, warningMessage);
[modelFolder, ~, ~] = fileparts(modelPath);
error("mlut:sl:modelLoadDependenciesMissing", ...
    "Model '%s' could not be loaded cleanly because Simulink could not resolve required dependencies.%s\n\nAdd '%s' and any dependency folders to the MATLAB path or project path, then load the model again.", ...
    modelName, details, string(modelFolder));
end

function removeTempFolder(folder)
if isfolder(folder)
    rmdir(folder, "s");
end
end

function modelName = modelNameFromInput(modelOrPath)
modelOrPath = strip(modelOrPath);
[~, name, ext] = fileparts(modelOrPath);
if ext ~= "" || isfile(modelOrPath)
    modelName = string(name);
    return
end

rootName = extractBefore(modelOrPath + "/", "/");
[~, modelName] = fileparts(rootName);
modelName = string(modelName);
end
