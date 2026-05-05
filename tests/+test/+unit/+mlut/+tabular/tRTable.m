classdef tRTable < matlab.unittest.TestCase

    methods (Test)

        function tDefaultIsEmpty(testCase)
            r = mlut.tabular.RTable();
            testCase.verifyEqual(size(r), [0 0])
            testCase.verifyClass(r.DataTable, "table")
        end

        function tConstructFromTable(testCase)
            t = table([1; 2; 3], ["a"; "b"; "c"], 'VariableNames', ["x", "y"]);
            r = mlut.tabular.RTable(t);
            testCase.verifyEqual(size(r), [3 2])
            testCase.verifyEqual(r.DataTable, t)
        end

        function tConstructFromAnotherRTable(testCase)
            % The constructor unwraps RTabular inputs; round-trip through
            % the wrapper must be lossless.
            t = table([1; 2], 'VariableNames', "x");
            r1 = mlut.tabular.RTable(t);
            r2 = mlut.tabular.RTable(r1);
            testCase.verifyEqual(r2.DataTable, t)
        end

        function tEmptyStaticReturnsEmpty(testCase)
            r = mlut.tabular.RTable.empty();
            testCase.verifyClass(r, "mlut.tabular.RTable")
            testCase.verifyEqual(size(r), [0 0])
        end

        function tDotReferenceKnownColumn(testCase)
            t = table([10; 20; 30], 'VariableNames', "x");
            r = mlut.tabular.RTable(t);
            testCase.verifyEqual(r.x, [10; 20; 30])
        end

        function tDotReferenceUnknownColumnReturnsNaN(testCase)
            % Robust contract: unknown columns yield a NaN column matching
            % the table's height rather than erroring.
            t = table([10; 20; 30], 'VariableNames', "x");
            r = mlut.tabular.RTable(t);
            testCase.verifyEqual(r.notAColumn, NaN(3, 1))
        end

        function tDotAssignDeletesWhenRhsIsEmpty(testCase)
            t = table([1; 2], [3; 4], 'VariableNames', ["x", "y"]);
            r = mlut.tabular.RTable(t);
            r.x = [];
            testCase.verifyEqual(string(r.DataTable.Properties.VariableNames), "y")
        end

        function tDotAssignBroadcastsScalar(testCase)
            t = table([1; 2; 3], 'VariableNames', "x");
            r = mlut.tabular.RTable(t);
            r.x = 7;
            testCase.verifyEqual(r.DataTable.x, [7; 7; 7])
        end

        function tParenAssignBeyondEndAddsRows(testCase)
            % parenAssign grows the underlying table when assigning past
            % its end so `r(N+k,:) = ...` succeeds.
            r = mlut.tabular.RTable(table([1; 2], 'VariableNames', "x"));
            r(4, :) = {99};
            testCase.verifyEqual(height(r.DataTable), 4)
            testCase.verifyEqual(r.DataTable.x(4), 99)
        end

    end

end
