function bus = loadBus(model, name)
arguments
    model (1,1) string
    name (1,1) string
end

[~, cleanup] = mlut.sl.loadSystem(model); %#ok<NASGU>
[~, modelName] = fileparts(model);
if strlength(modelName) == 0
    modelName = model;
end

busName = strtrim(erase(name, "Bus:"));

try
    bus = Simulink.data.evalinGlobal(modelName, busName);
catch
    try
        modelWorkspace = get_param(modelName, "ModelWorkspace");
        bus = modelWorkspace.getVariable(char(busName));
    catch
        bus = [];
    end
end

if numel(bus) ~= 1
    bus = Simulink.Bus.empty(1, 0);
elseif isa(bus, "Simulink.Bus")
    bus.Description = busName;
end
end
