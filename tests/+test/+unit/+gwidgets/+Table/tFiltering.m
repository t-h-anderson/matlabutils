classdef tFiltering < test.WithExampleTables
    % Test filtering table entries in a headless table.

    methods (Test)

        function tSimpleFilter(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());

            testCase.verifyEqual(t.Filter, "")
            testCase.verifyEqual(t.RowFilterIndices, repelem(true, 1, 5))

            t.Filter = "String=x";

            testCase.verifyEmpty(t.Groups)
            testCase.verifyEqual(t.Filter, "String=x")
            testCase.assertSize(t.DisplayData, [3 4])
            testCase.verifyEqual(t.Data(t.Data.String=="x",:), t.DisplayData)
            testCase.verifyEqual(t.RowFilterIndices', t.Data.String=="x")
        end

        function tRemoveAppliedFilter(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());

            t.Filter = "Numerical>4";

            testCase.verifySize(t.DisplayData, [1 4])

            t.Filter = "";
            testCase.verifyEqual(t.DisplayData, t.Data)
            testCase.verifyEqual(t.RowFilterIndices, repelem(true, 1, 5))
        end

        function tSequentialFiltering(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());

            t.Filter = "Numerical>1";
            t.Filter = "String=x";
            
            testCase.assertSize(t.DisplayData, [3 4])
            testCase.verifyEqual(t.Filter, "String=x")
        end

        function tFilterEmptyTable(testCase)
            t = gwidgets.Table(Data=table.empty(0,2));
            testCase.verifyEqual(t.Data, t.DisplayData)
            testCase.verifySize(t.RowFilterIndices, [1 0])

            t.Filter = "Var1>2";

            testCase.verifyEqual(t.Data, t.DisplayData)
            testCase.verifySize(t.RowFilterIndices, [1 0])
        end

        function tInvalidFilterSyntax(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());

            t.Filter = "Test!&'£";

            testCase.verifyEqual(t.Data, t.DisplayData)
            testCase.verifyEqual(t.RowFilterIndices, repelem(true, 1, 5))
        end

        function tAllEntriesFiltered(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());

            t.Filter = "Numerical>10";

            testCase.assertSize(t.DisplayData, [0 4])
            testCase.verifyEqual(t.RowFilterIndices, repelem(false, 1, 5))
        end

        function tEditDataAfterFiltering(testCase)
            t = gwidgets.Table(Data=testCase.multivariableData());
            t.Filter = "String=x";
            t.Data.String = repelem("x", 5, 1);

            testCase.verifySize(t.DisplayData, [5 4])
        end

        function tReplaceDataAfterFiltering(testCase)
            data = testCase.multivariableData();
            t = gwidgets.Table(Data=data);
            t.Filter = "Numerical>3";

            newdata = [data; data];
            newdata.Properties.VariableNames{3} = 'Boolean';
            newdata.Logical = repelem(false, 10, 1);
            t.Data = newdata;

            testCase.assertSize(t.DisplayData, [4 5])
            testCase.verifyEqual(t.Filter, "Numerical>3")
            testCase.verifyEqual(t.DisplayData.Numerical, [4 5 4 5]')
        end

    end

end