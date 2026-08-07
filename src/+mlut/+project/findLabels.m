function [labels, isFound] = findLabels(filename, thisProj)
arguments
    filename (1,1) string
    thisProj = currentProject
end

file = which(filename);
if isempty(file)
    isFound = false;
    labels = string.empty(1,0);
    return
end

file = thisProj.findFiles(file, "OutputFormat", "ProjectFile");
if isempty(file)
    isFound = false;
    labels = string.empty(1,0);
    return
end

isFound = true;
labels = string([file.Labels.CategoryName]) + "/" + string([file.Labels.Name]);
end
