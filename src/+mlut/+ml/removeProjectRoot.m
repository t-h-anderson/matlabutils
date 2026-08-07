function pth = removeProjectRoot(pth)
arguments
    pth (1,1) string
end

rootFolder = projectRoot();
pth = erase(pth, rootFolder);
pth = fullfile(".", pth);
end

function rootFolder = projectRoot()
try
    prj = currentProject();
    rootFolder = string(prj.RootFolder);
catch me
    if string(me.identifier) ~= "MATLAB:project:api:NoProjectCurrentlyLoaded"
        rethrow(me);
    end
    rootFolder = defaultProjectRoot();
end
end

function rootFolder = defaultProjectRoot()
rootFolder = fileparts(fileparts(fileparts(fileparts(mfilename("fullpath")))));
rootFolder = string(rootFolder);
end
