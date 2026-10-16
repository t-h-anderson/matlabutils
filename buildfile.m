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
%TESTTASK Run tests with project source on the path.

originalPath = path();
cleanupObj = onCleanup(@() path(originalPath));

addpath(genpath("src"));
addpath("tests");

testSuites = ["tests/+test/+unit", "tests/+test/+integration", "tests/+test/+system"];
suiteResults = cell(1, numel(testSuites));
for iSuite = 1:numel(testSuites)
    suiteResults{iSuite} = runtests(testSuites(iSuite), IncludeSubfolders=true);
end
results = [suiteResults{:}];
if any([results.Failed]) || any([results.Incomplete])
    error("MLUT:build:testFailure", "Test suite failed.");
end

end

function performanceTask(~)
%PERFORMANCETASK Run performance benchmarks.

originalPath = path();
cleanupObj = onCleanup(@() path(originalPath));

addpath(genpath("src"));
addpath("tests");

suite = testsuite("tests/+test/+performance", IncludeSubfolders=true);
results = runperf(suite);
disp(results)

end

function packageTask(context)
%PACKAGETASK Package src and doc as releases/<ShortName> <Version>.mltbx.
%   Toolbox metadata, including the version, lives in deploy/tbxdescription.json.

projectRoot = context.Plan.RootFolder;
prj = currentProject();

meta = jsondecode(fileread(fullfile(projectRoot, "deploy", "tbxdescription.json")));
meta.ToolboxMatlabPath = fullfile(projectRoot, meta.ToolboxMatlabPath);
meta.ToolboxFolder = fullfile(projectRoot, meta.ToolboxFolder);
meta.ToolboxGettingStartedGuide = fullfile(projectRoot, "doc", ...
    meta.ToolboxGettingStartedGuide);
% Releases are attached to GitHub releases, not committed (*.mltbx is ignored).
releaseFolder = fullfile(projectRoot, "releases");
if ~isfolder(releaseFolder)
    mkdir(releaseFolder);
end
meta.OutputFile = fullfile(releaseFolder, ...
    meta.ToolboxShortName + " " + meta.ToolboxVersion + ".mltbx");

toolboxFolder = meta.ToolboxFolder;
toolboxID = meta.Identifier;
meta = rmfield(meta, ["Identifier", "ToolboxFolder", "ToolboxShortName"]);
opts = matlab.addons.toolbox.ToolboxOptions(toolboxFolder, toolboxID, meta);

% Ship only the source and documentation that belong to the project.
isShipped = startsWith(opts.ToolboxFiles, fullfile(projectRoot, "src")) | ...
    startsWith(opts.ToolboxFiles, fullfile(projectRoot, "doc"));
opts.ToolboxFiles = opts.ToolboxFiles(isShipped);
opts.ToolboxFiles = opts.ToolboxFiles(ismember(opts.ToolboxFiles, [prj.Files.Path]));

matlab.addons.toolbox.packageToolbox(opts);
fprintf(1, "[+] %s\n", opts.OutputFile);

licenseText = fileread(fullfile(projectRoot, "license.txt"));
mlAddonSetLicense(char(opts.OutputFile), struct("type", "Custom", "text", licenseText));

end
