function plan = buildfile
%BUILDFILE Build, analyze, test, and package MATLAB Utils.

plan = buildplan(localfunctions);
plan.DefaultTasks = "test";

end

function checkTask(~)
%CHECKTASK Run Code Analyzer on source files.

files = dir(fullfile("src", "**", "*.m"));
hasIssues = false;

for k = 1:numel(files)
    filePath = fullfile(files(k).folder, files(k).name);
    issues = checkcode(filePath, "-struct");
    if isempty(issues)
        continue
    end

    hasIssues = true;
    fprintf("%s\n", filePath);
    for i = 1:numel(issues)
        fprintf("  L%d: %s\n", issues(i).line, issues(i).message);
    end
end

if hasIssues
    warning("MLUT:build:codeIssues", "Code Analyzer reported issues.");
end

end

function testTask(~)
%TESTTASK Run unit tests with project source on the path.

originalPath = path();
cleanupObj = onCleanup(@() path(originalPath));

addpath(genpath("src"));
addpath("tests");

results = runtests("tests/+test/+unit", IncludeSubfolders=true);
if any([results.Failed]) || any([results.Incomplete])
    error("MLUT:build:testFailure", "Unit test suite failed.");
end

end

function packageTask(~)
%PACKAGETASK Package the MATLAB toolbox project.

matlab.addons.toolbox.packageToolbox("MLUT.prj");

end
