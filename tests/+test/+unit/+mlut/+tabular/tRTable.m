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

        function tDisplayAndPropertiesDelegateToTable(testCase)
            t = table([1; 2], 'VariableNames', "x");
            r = mlut.tabular.RTable(t);

            props = r.Properties;
            props.Description = "robust table";
            r.Properties = props;

            testCase.verifyEqual(string(r.Properties.Description), "robust table")
            testCase.verifyWarningFree(@()disp(r))
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

        function tDotReferenceDimensionProperty(testCase)
            t = table([10; 20; 30], 'VariableNames', "x");
            t.Properties.DimensionNames = ["Sample", "Variables"];
            r = mlut.tabular.RTable(t);

            testCase.verifyEqual(r.Sample, t.Properties.RowNames)
        end

        function tDotReferenceNestedIndexing(testCase)
            t = table(["alpha"; "beta"; "gamma"], 'VariableNames', "name");
            r = mlut.tabular.RTable(t);

            testCase.verifyEqual(r.name(2), "beta")
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

        function tDotAssignVectorReplacesColumn(testCase)
            t = table([1; 2; 3], 'VariableNames', "x");
            r = mlut.tabular.RTable(t);

            r.x = [4; 5; 6];

            testCase.verifyEqual(r.DataTable.x, [4; 5; 6])
        end

        function tDotAssignCopiesWrappedTableColumn(testCase)
            t = table([1; 2], 'VariableNames', "x");
            replacement = mlut.tabular.RTable(table([5; 6], 'VariableNames', "y"));
            r = mlut.tabular.RTable(t);

            r.x = replacement;

            testCase.verifyEqual(r.DataTable.x, [5; 6])
        end

        function tParenReferenceAddsMissingRowsAndColumns(testCase)
            t = table([10; 20], ["a"; "b"], 'VariableNames', ["x", "label"]);
            r = mlut.tabular.RTable(t);

            result = r([1 3], ["x", "missing"]);
            tbl = result.value();

            testCase.verifyEqual(string(tbl.Properties.VariableNames), ["x", "missing"])
            testCase.verifyEqual(tbl.x, [10; missing])
            testCase.verifyEqual(tbl.missing, [NaN; missing])
        end

        function tParenReferenceWithNumericColumnsAddsMissingColumn(testCase)
            t = table([10; 20], 'VariableNames', "x");
            r = mlut.tabular.RTable(t);

            result = r(:, [1 3]);
            tbl = result.value();

            testCase.verifyEqual(string(tbl.Properties.VariableNames), ["x", "Var3"])
            testCase.verifyEqual(tbl.Var3, NaN(2, 1))
        end

        function tParenReferenceWithColonKeepsAllColumns(testCase)
            t = table([10; 20], ["a"; "b"], 'VariableNames', ["x", "label"]);
            r = mlut.tabular.RTable(t);

            testCase.verifyEqual(r(:, :).value(), t)
        end

        function tBraceReferenceUsesRobustParenReference(testCase)
            t = table([10; 20], [30; 40], 'VariableNames', ["x", "y"]);
            r = mlut.tabular.RTable(t);

            values = r{[2 3], ["y", "z"]};

            testCase.verifyEqual(values, [40 NaN; missing missing])
        end

        function tParenDeleteRemovesColumn(testCase)
            t = table([1; 2], [3; 4], 'VariableNames', ["x", "y"]);
            r = mlut.tabular.RTable(t);

            r(:, "x") = [];

            testCase.verifyEqual(string(r.DataTable.Properties.VariableNames), "y")
        end

        function tParenAssignBeyondEndAddsRows(testCase)
            % parenAssign grows the underlying table when assigning past
            % its end so `r(N+k,:) = ...` succeeds.
            r = mlut.tabular.RTable(table([1; 2], 'VariableNames', "x"));
            r(4, :) = {99};
            testCase.verifyEqual(height(r.DataTable), 4)
            testCase.verifyEqual(r.DataTable.x(4), 99)
        end

        function tValueTableTimetableAndSum(testCase)
            t = table([1; 2; 3], seconds([1; 2; 3]), 'VariableNames', ["x", "Time"]);
            r = mlut.tabular.RTable(t);

            testCase.verifyEqual(r.value(), t)
            testCase.verifyEqual(r.table(), t)
            testCase.verifyError(@()r.timetable(RowTimes="Time"), "MATLAB:table2timetable:NonTable")
            testCase.verifyEqual(r.sum().value().x, 6)
        end

        function tStaticTabularFactories(testCase)
            tbl = mlut.tabular.RTable.tabular([1; 2], 'VariableNames', {'x'});
            fromArray = mlut.tabular.RTable.array2tabular([1 2; 3 4]);
            emptyTbl = mlut.tabular.RTable.tabularEmpty(0, 2);

            testCase.verifyClass(tbl, "table")
            testCase.verifyEqual(tbl.x, [1; 2])
            testCase.verifyClass(fromArray, "table")
            testCase.verifySize(emptyTbl, [0 2])
        end

        function tSingleInputCatReturnsInput(testCase)
            r = mlut.tabular.RTable(table([1; 2], 'VariableNames', "A"));

            tall = cat(1, r);
            wide = cat(2, r);

            testCase.verifyEqual(tall.value(), r.value())
            testCase.verifyEqual(wide.value(), r.value())
        end

        function tHorzcatToleratesRowMismatches(testCase)
            left = mlut.tabular.RTable(table([1; 2], 'VariableNames', "A"));
            right = mlut.tabular.RTable(table(["x"; "y"; "z"], 'VariableNames', "B"));

            result = [left, right];
            tbl = result.value();

            testCase.verifySize(tbl, [3 2])
            testCase.verifyEqual(tbl.A, [1; 2; NaN])
            testCase.verifyEqual(tbl.B, ["x"; "y"; "z"])
        end

        function tHorzcatDropsFullyMissingDuplicateColumns(testCase)
            left = table([1; 2], [NaN; NaN], 'VariableNames', ["A", "B"]);
            right = table([3; 4], 'VariableNames', "B");

            result = [mlut.tabular.RTable(left), mlut.tabular.RTable(right)];
            tbl = result.value();

            testCase.verifyEqual(string(tbl.Properties.VariableNames), ["A", "B"])
            testCase.verifyEqual(tbl.B, [3; 4])
        end

        function tHorzcatAndVertcatAcceptMultipleInputs(testCase)
            a = mlut.tabular.RTable(table([1; 2], 'VariableNames', "A"));
            b = mlut.tabular.RTable(table([3; 4], 'VariableNames', "B"));
            c = mlut.tabular.RTable(table([5; 6], 'VariableNames', "C"));

            wide = [a, b, c];
            tall = [a; b; c];

            testCase.verifyEqual(string(wide.value().Properties.VariableNames), ["A", "B", "C"])
            testCase.verifyEqual(string(tall.value().Properties.VariableNames), ["A", "B", "C"])
            testCase.verifySize(tall.value(), [6 3])
        end

        function tVertcatPadsTypedMissingColumns(testCase)
            left = table((1:2)', ...
                datetime(2020, 1, (1:2)'), ...
                categorical(["x"; "y"]), ...
                [true; false], ...
                'VariableNames', ["A", "D", "C", "L"]);
            right = table((3:4)', 'VariableNames', "A");

            result = [mlut.tabular.RTable(left); mlut.tabular.RTable(right)];
            tbl = result.value();

            testCase.verifyClass(tbl.D, "datetime")
            testCase.verifyClass(tbl.C, "categorical")
            testCase.verifyClass(tbl.L, "logical")
            testCase.verifyTrue(all(isnat(tbl.D(3:4))))
            testCase.verifyTrue(all(isundefined(tbl.C(3:4))))
            testCase.verifyEqual(tbl.L(3:4), [false; false])
        end

        function tVertcatAlignsColumnOrderByName(testCase)
            left = table((1:2)', 'VariableNames', "B");
            right = table((3:4)', 'VariableNames', "A");

            result = [mlut.tabular.RTable(left); mlut.tabular.RTable(right)];
            tbl = result.value();

            testCase.verifyEqual(string(tbl.Properties.VariableNames), ["B", "A"])
            testCase.verifyEqual(tbl.B, [1; 2; NaN; NaN])
            testCase.verifyEqual(tbl.A, [NaN; NaN; 3; 4])
        end

        function tVertcatPadsZeroRowCellColumn(testCase)
            left = mlut.tabular.RTable(table(zeros(0, 1), 'VariableNames', "A"));
            right = mlut.tabular.RTable(table({10; 20}, 'VariableNames', "B"));

            result = [left; right];
            tbl = result.value();

            testCase.verifySize(tbl, [2 2])
            testCase.verifyEqual(tbl.A, [NaN; NaN])
            testCase.verifyEqual(tbl.B, {10; 20})
        end

        function tVertcatPadsCellColumns(testCase)
            left = mlut.tabular.RTable(table([1; 2], 'VariableNames', "A"));
            right = mlut.tabular.RTable(table({10; 20}, 'VariableNames', "B"));

            result = [left; right];
            tbl = result.value();

            testCase.verifyEqual(tbl.B(3:4), {10; 20})
            testCase.verifyTrue(ismissing(tbl.B{1}))
            testCase.verifyTrue(ismissing(tbl.B{2}))
        end

        function tDataTypesReturnsTableVariableTypes(testCase)
            t = table([1; 2], ["a"; "b"], 'VariableNames', ["x", "label"]);

            testCase.verifyEqual(mlut.tabular.RTable.dataTypes(t), ["double", "string"])
        end

    end

end
