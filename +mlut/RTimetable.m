classdef RTimetable < mlut.RTabular
    
    methods
        function obj = CycleData(tbl)
            arguments
                tbl timetable = timetable('Size', [0,0], 'VariableTypes', [], 'RowTimes', seconds(nan(0,0)))
            end
            obj.DataTable = obj.vertcat_(tbl, obj.defaultEmptyTable());
        end

        function val = table(obj)
            val = timetable2table(obj.DataTable);
        end

        function val = timetable(obj, varargin)
            val = obj.DataTable;
        end
    end

    methods (Static)
        function obj = empty()
            obj = mlut.RTimetable(timetable('Size', [0,0], 'VariableTypes', [], 'RowTimes', seconds(nan(0,0))));
        end

    end

    methods (Static)

        function obj = create(varargin)
            obj = mlut.RTimetable(varargin{:});
        end

        function tbl = tabularEmpty(varargin)
            tbl = timetable.empty(varargin{:});
        end

        function tbl = tabular(varargin)
            args = mlut.RTabular.cellstring2char(varargin);
            tbl = timetable(args{:});
        end

        function tbl = array2tabular(varargin)
            tbl = array2timetable(varargin{:});
        end

    end
    methods (Static, Hidden)
        function emptyTable = defaultEmptyTable()

            variableNames = string.empty(1,0);

            % Create an empty table with double data type for each variable
            emptyTable = timetable.empty(0, numel(variableNames));
            emptyTable.Properties.VariableNames = variableNames;
            emptyTable.Properties.DimensionNames(1) = "Time [sec]";
            emptyTable.("Time [sec]") = seconds(NaN(0,0));

        end

    end

end

