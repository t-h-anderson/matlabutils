function val = isEmptyOrMissing(v, nvp)
arguments
    v
    nvp.VectorMissing (1,1) logical = false
    nvp.Indicator (1,:)
    nvp.MissingFunc (1,1) function_handle
end
    
val = isempty(v);

if val
    % Isempty
    return
elseif nvp.VectorMissing
    if isfield(nvp, "Indicator")
        val = all(ismissing(v, nvp.Indicator));
    else
        val = all(ismissing(v));
    end
elseif isscalar(v)
    if isfield(nvp, "Indicator")
        val = ismissing(v, nvp.Indicator);
    else
        val = ismissing(v);
    end
end

if val
    % Is missing
    return
else
    % Use missing function
    if isfield(nvp, "MissingFunc")
        if nvp.VectorMissing
            val = all(arrayfun(@(x) nvp.MissingFunc(x), v));
        elseif isscalar(v)
            val = nvp.MissingFunc(v);
        end
    end
end

end

