classdef WithExampleTables < matlab.unittest.TestCase

    methods (Static)

        function tbl = defaultTable(parent)
            data = test.WithExampleTables.complexData();
            tbl = gwidgets.Table(Parent=parent, ...
                Data=data, ShowRowFilter=true, ShowEmptyGroups=false);
        end

        function data = stringData()
            data = table((1:10)', ["a","b","a","b","c","a","c","c","c","a"]');
        end

        function data = numericalData()
            data = table((1:10)', [1 2 3 2 3 2 1 1 2 2]', ...
                int32(1:10)');
        end 

        function data = complexData()
            % Larger table with data of different type, including
            % categoricals, Boolean, numerical, string.
            load("patients.mat");
            t = table(Location, Gender, LastName, Age, ...
                SelfAssessedHealthStatus, Height, Weight, ...
                Smoker, Systolic, Diastolic);
            t.Location = categorical(t.Location);
            t.Gender = categorical(t.Gender);
            t.Age = int16(t.Age);
            t.LastName = string(t.LastName);
            t.Height = single(t.Height);
            data = sortrows(t, {'Location','Gender'} ,'descend');
        end

        function data = categoricalData()
            data = table((1:10)', ["a","b","a","b","c","a","c","c","c","a"]');
            data.Var2 = categorical(data.Var2);
        end

        function data = logicalData()
            data = table((1:5)', [1 0 0 1 0]');
            data.Var2 = logical(data.Var2);
        end

        function data = multivariableData()
            data = table((1:5)', categorical(["a","b","b","a","a"])', ...
                logical([1 0 1 0 1]'), ["y","x","x","x","y"]');
            data.Properties.VariableNames = ["Numerical", "Categorical", ...
                "Logical", "String"];
        end

        function data = collapsibleData()
            data = table([1 2 1 3 3 2]', [0 1 0 1 0 1]');
        end

        function data = sortableData()
            data = table([4 2 3 1]', [true false true true]', ["b" "b" "a" "b"]');
        end

    end

end