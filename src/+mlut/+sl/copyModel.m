function [copiedArtefacts, cleanupObjs] = copyModel(modelName, nvp)
%COPYMODEL Copy a Simulink model, its data dictionary, and model references.

arguments
    modelName (1,1) string = "MyModel"
    nvp.Destination (1,1) string = fullfile(pwd, "modelPrepFolder")
end

makeCleanup = nargout > 1;
cleanupObjs = onCleanup.empty(1,0);
copiedArtefacts = string.empty(1,0);

if ismissing(modelName) || modelName == ""
    error("mlut:sl:copyModel:modelNotSpecified", ...
        "No model was specified to copy.")
end

destFolder = nvp.Destination;
if ~isfolder(destFolder)
    mkdir(destFolder);
end

modelPath = resolveModelFile(modelName);
[~, modelBaseName, modelExt] = fileparts(modelPath);
copiedModel = string(fullfile(destFolder, modelBaseName + modelExt));
sourceFolder = string(fileparts(modelPath));
pathCleanupObj = addFolderToPath(sourceFolder); %#ok<NASGU>

[~, modelCleanup] = mlut.sl.Model.open(modelPath); %#ok<ASGLU>

if modelPath ~= copiedModel
    copyRequiredFile(modelPath, copiedModel, "model");
    copiedArtefacts(end+1) = copiedModel;
    if makeCleanup
        cleanupObjs(end+1) = onCleanup(@() deleteIfFile(copiedModel));
    end
end

slddName = mlut.sl.DataDictionary.nameForModel(modelBaseName);
if slddName ~= ""
    copiedArtefacts = copyDataDictionary(slddName, destFolder, copiedArtefacts);
end

modelRefs = string(find_mdlrefs(modelBaseName, ReturnTopModelAsLastElement=false));
for i = 1:numel(modelRefs)
    if makeCleanup
        [newCopiedArtefacts, newCleanupObjs] = mlut.sl.copyModel(modelRefs(i), Destination=destFolder);
        cleanupObjs = [cleanupObjs, newCleanupObjs]; %#ok<AGROW>
    else
        newCopiedArtefacts = mlut.sl.copyModel(modelRefs(i), Destination=destFolder);
    end
    copiedArtefacts = [copiedArtefacts, newCopiedArtefacts]; %#ok<AGROW>
end

    function copiedArtefacts = copyDataDictionary(slddName, destFolder, copiedArtefacts)
        slddPath = string(which(slddName));
        if slddPath == ""
            sourceFolder = string(fileparts(modelPath));
            candidate = string(fullfile(sourceFolder, slddName));
            if isfile(candidate)
                slddPath = candidate;
            end
        end

        if slddPath == ""
            warning("mlut:sl:copyModel:dataDictionaryNotFound", ...
                "Could not find data dictionary to copy: %s", slddName);
            return
        end

        [~, slddBaseName, slddExt] = fileparts(slddPath);
        copiedDictionary = string(fullfile(destFolder, slddBaseName + slddExt));
        if isfile(copiedDictionary)
            return
        end

        copyRequiredFile(slddPath, copiedDictionary, "data dictionary");
        copiedArtefacts(end+1) = copiedDictionary;
        if makeCleanup
            cleanupObjs(end+1) = onCleanup(@() deleteIfFile(copiedDictionary));
        end
    end
end

function modelPath = resolveModelFile(modelName)
modelName = strip(modelName);
if isfile(modelName)
    modelPath = string(modelName);
    return
end

[~, modelBaseName, modelExt] = fileparts(modelName);
if modelExt ~= ""
    modelStem = modelBaseName;
else
    modelStem = modelName;
end

modelPath = string(which(modelStem));
if modelPath ~= "" && isfile(modelPath)
    return
end

for ext = [".slx", ".mdl"]
    candidate = modelStem + ext;
    if isfile(candidate)
        modelPath = string(candidate);
        return
    end
end

error("mlut:sl:copyModel:modelNotFound", ...
    "Model '%s' was not found on the MATLAB path or file system.", modelName);
end

function copyRequiredFile(sourcePath, destinationPath, artefactType)
[success, message] = copyfile(sourcePath, destinationPath);
if ~success
    error("mlut:sl:copyModel:copyFailed", ...
        "Could not copy %s '%s' to '%s': %s", ...
        artefactType, sourcePath, destinationPath, message);
end
end

function deleteIfFile(filePath)
if isfile(filePath)
    delete(filePath);
end
end

function cleanupObj = addFolderToPath(folder)
arguments
    folder (1,1) string
end

cleanupObj = onCleanup.empty(1,0);
if folder == ""
    return
end

pathFolders = string(strsplit(path, pathsep));
if any(pathFolders == folder)
    return
end

addpath(folder);
cleanupObj = onCleanup(@() rmpath(folder));
end
