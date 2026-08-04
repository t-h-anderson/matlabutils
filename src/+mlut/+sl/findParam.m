function value = findParam(model, name)
arguments
    model (1,1) string
    name (1,1) string
end

[~, cleanup] = mlut.sl.loadSystem(model); %#ok<NASGU>
[~, modelName] = fileparts(model);
if strlength(modelName) == 0
    modelName = model;
end

set_param(modelName, "SimulationCommand", "Update");
where = Simulink.findVars(modelName, "Name", name, "SearchMethod", "cached");
if isempty(where)
    error("mlut:sl:findParam:NotFound", ...
        "Could not resolve parameter %s in model %s.", name, modelName);
end
if numel(where) ~= 1
    error("mlut:sl:findParam:Ambiguous", ...
        "Found %d definitions for parameter %s in model %s.", ...
        numel(where), name, modelName);
end

sourceType = lower(string(where.SourceType));
switch true
    case sourceType == "model workspace"
        modelWorkspace = get_param(modelName, "ModelWorkspace");
        value = iResolveValue(modelWorkspace.getVariable(char(name)));
    case contains(sourceType, "data dictionary")
        dictionary = Simulink.data.dictionary.open(where.Source);
        cleanupDictionary = onCleanup(@() dictionary.close()); %#ok<NASGU>
        designData = dictionary.getSection("Design Data");
        entry = designData.getEntry(char(where.Name));
        value = iResolveValue(entry.getValue());
    case sourceType == "base workspace"
        error("mlut:sl:findParam:BaseWorkspaceUnsupported", ...
            "Parameter %s resolves from the base workspace, which is not supported.", ...
            name);
    otherwise
        error("mlut:sl:findParam:UnsupportedSource", ...
            "Parameter %s resolves from unsupported source type %s.", ...
            name, where.SourceType);
end
end

function value = iResolveValue(value)
if isa(value, "Simulink.Parameter")
    value = value.Value;
end
end
