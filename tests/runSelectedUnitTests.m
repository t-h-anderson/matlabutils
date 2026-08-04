restoredefaultpath
root = fileparts(fileparts(mfilename("fullpath")));
addpath(genpath(fullfile(root, "src")))
addpath(genpath(fullfile(root, "tests")))

tests = {
    fullfile(root, "tests", "+test", "+unit", "+mlut", "+codegen", "tPadToBoundary.m")
    fullfile(root, "tests", "+test", "+unit", "+mlut", "+sl", "tLoadSystem.m")
    fullfile(root, "tests", "+test", "+unit", "+mlut", "+sl", "tLoadBus.m")
    fullfile(root, "tests", "+test", "+unit", "+mlut", "+sl", "tFindParam.m")
    fullfile(root, "tests", "+test", "+unit", "+mlut", "+sl", "+wrapper", "tUtilities.m")
    };

suite = matlab.unittest.TestSuite.fromFile(tests{1});
for i = 2:numel(tests)
    suite = [suite, matlab.unittest.TestSuite.fromFile(tests{i})]; %#ok<AGROW>
end

runner = matlab.unittest.TestRunner.withTextOutput("OutputDetail", matlab.unittest.Verbosity.Detailed);
results = runner.run(suite);
assert(all([results.Passed]), "Selected mlut unit tests failed.");
