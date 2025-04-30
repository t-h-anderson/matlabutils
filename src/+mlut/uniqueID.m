function id = uniqueID(n)
    
    arguments
        n (1,1) uint32 = 1 % changed to 32 bit to protect for large arrays
    end
    
    id = matlab.lang.internal.uuid(n, 1);
    
end