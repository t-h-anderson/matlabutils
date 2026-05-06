function val = isEmptyOrMissing(v, nvp)
% Indicator and MissingFunc are intentionally left without defaults so
% that isfield(nvp, ...) distinguishes "not supplied" from "supplied".
arguments
    v
    nvp.VectorMissing (1,1) logical = false
    nvp.Indicator (1,:)
    nvp.MissingFunc (1,1) function_handle
end

val = isempty(v);
if val
    return
end

hasIndicator = isfield(nvp, "Indicator");
if nvp.VectorMissing
    if hasIndicator
        val = all(ismissing(v, nvp.Indicator));
    else
        val = all(ismissing(v));
    end
elseif isscalar(v)
    if hasIndicator
        val = ismissing(v, nvp.Indicator);
    else
        val = ismissing(v);
    end
end

if val || ~isfield(nvp, "MissingFunc")
    return
end

if nvp.VectorMissing
    val = all(arrayfun(nvp.MissingFunc, v));
elseif isscalar(v)
    val = nvp.MissingFunc(v);
end

end

