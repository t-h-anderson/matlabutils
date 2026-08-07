function cleanupObjs = setVariantWarningsTemporarily(state)
%SETVARIANTWARNINGSTEMPORARILY Temporarily configure variant-related warnings.

arguments
    state (1,1) string {mustBeMember(state, ["on", "off", "error"])}
end

warnings = ["Simulink:Commands:FindSystemDefaultVariantsOptionWithVariantModel", ...
    "Simulink:Commands:FindSystemDefaultVariantsOptionWithVariantModel", ...
    "Simulink:Commands:FindSystemAllVariantsRemoval", ...
    "Simulink:Commands:FindSystemVariantsOptionRemoval"];

s = cell(1, numel(warnings));
cleanupObjs = cell(1, numel(warnings));
for i = 1:numel(warnings)
    s{i} = warning("query", warnings(i));
    cleanupObjs{i} = onCleanup(@() warning(s{i}));
    warning(char(state), warnings(i));
end

end
