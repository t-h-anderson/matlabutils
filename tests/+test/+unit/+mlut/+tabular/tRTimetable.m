classdef tRTimetable < matlab.unittest.TestCase

    methods (Test)
        function tDefaultIsEmptyTimetable(testCase)
            r = mlut.tabular.RTimetable();

            testCase.verifyClass(r.DataTable, "table")
            testCase.verifyEqual(size(r), [0 0])
        end

        function tEmptyStaticReturnsEmptyTimetable(testCase)
            r = mlut.tabular.RTimetable.empty();

            testCase.verifyClass(r, "mlut.tabular.RTimetable")
            testCase.verifyClass(r.DataTable, "timetable")
            testCase.verifyEqual(size(r), [0 0])
        end

        function tConstructAndConvert(testCase)
            tt = timetable(seconds([1; 2]), [10; 20], VariableNames="x");
            r = mlut.tabular.RTimetable(tt);

            testCase.verifyEqual(r.timetable(), tt)
            testCase.verifyEqual(r.table(), timetable2table(tt))
        end

        function tCreateAndFactories(testCase)
            tt = timetable(seconds([1; 2]), [10; 20], VariableNames="x");
            r = mlut.tabular.RTimetable.create(tt);
            emptyTbl = mlut.tabular.RTimetable.tabularEmpty(0, 1);
            fromTabular = mlut.tabular.RTimetable.tabular(seconds([1; 2]), [3; 4], 'VariableNames', {'x'});
            fromArray = mlut.tabular.RTimetable.array2tabular([3; 4], RowTimes=seconds([1; 2]));

            testCase.verifyEqual(r.DataTable, tt)
            testCase.verifyClass(emptyTbl, "timetable")
            testCase.verifySize(emptyTbl, [0 1])
            testCase.verifyClass(fromTabular, "timetable")
            testCase.verifyEqual(fromTabular.x, [3; 4])
            testCase.verifyClass(fromArray, "timetable")
            testCase.verifyEqual(fromArray.Var1, [3; 4])
        end

        function tDefaultEmptyTableHasNamedTimeDimension(testCase)
            tt = mlut.tabular.RTimetable.defaultEmptyTable();

            testCase.verifyClass(tt, "timetable")
            testCase.verifyEqual(string(tt.Properties.DimensionNames(1)), "Time [sec]")
            testCase.verifyEqual(size(tt), [0 0])
        end
    end
end
