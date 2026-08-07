function sid = getSID(item)
%GETSID Return the Simulink identifier for a block, line, or handle.

arguments
    item
end

sid = string(Simulink.ID.getSID(item));
end
