function [mdlh, cleanup] = loadSystem(model)
arguments
    model (1,1) string
end

[target, modelName] = iNormalizeModel(model);

try
    if ~bdIsLoaded(modelName)
        mdlh = load_system(target);
        if nargout > 1
            cleanup = onCleanup(@() close_system(modelName, 0));
        end
    else
        mdlh = get_param(modelName, "Handle");
        cleanup = [];
    end
catch me
    error("mlut:sl:loadSystem:LoadFailed", ...
        "Failed to open model %s. %s", modelName, me.message);
end
end

function [target, modelName] = iNormalizeModel(model)
target = model;
[folder, name, ext] = fileparts(model);
if strlength(name) == 0
    modelName = model;
    return
end

modelName = string(name);
if strlength(folder) == 0 && strlength(ext) == 0
    target = modelName;
end
end
