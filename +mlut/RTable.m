classdef RTable < mlut.RTabular
    % Robust table

    methods
        function val = table(obj)
            val = obj.DataTable;
        end

        function val = timetable(obj, varargin)
            val = table2timetable(obj, varargin{:});
        end
    end

    methods (Static)
        function obj = empty()
            obj = mlut.RTable(table());
        end
    end

    methods (Static)

        function obj = create(varargin)
            obj = mlut.RTable(varargin{:});
        end

        function tbl = tabularEmpty(varargin)
            tbl = table.empty(varargin{:});
        end

        function tbl = tabular(varargin)
            args = mlut.RTabular.cellstring2char(varargin);
            tbl = table(args{:});
        end

        function tbl = array2tabular(varargin)
            tbl = array2table(varargin{:});
        end
    end

end

