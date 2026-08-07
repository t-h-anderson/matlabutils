function isAvailable = isDesktopAvailable()
%ISDESKTOPAVAILABLE True when MATLAB desktop GUI operations are available.

isAvailable = usejava("Desktop") == 1;
end
