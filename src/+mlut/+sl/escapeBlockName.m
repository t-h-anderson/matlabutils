function name = escapeBlockName(name)
%ESCAPEBLOCKNAME Escape slashes for use in Simulink block names.

arguments
    name (1,1) string
end

name = strrep(name, "/", "//"); % Allow slashes in the name
end
