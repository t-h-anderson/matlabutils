classdef (Abstract) RTabular < matlab.mixin.indexing.RedefinesParen ...
        & matlab.mixin.indexing.RedefinesDot ...
        & matlab.mixin.indexing.RedefinesBrace

    properties
        DataTable tabular = table.empty
    end

    properties (Dependent)
        Properties
    end

    methods
        function obj = RTabular(tbl)
            arguments
                tbl = table()
            end

            % Allow class to be created from another tabular
            if isa(tbl, "mlut.RTabular")
                tbl = tbl.DataTable;
            end
            
            if istabular(tbl)
                obj.DataTable = tbl;
            end

        end

        function disp(obj)
            disp(obj.DataTable);
        end

        function val = get.Properties(obj)
            val = obj.DataTable.Properties;
        end

        function obj = set.Properties(obj, val)
            obj.DataTable.Properties = val;
        end
    end

    methods (Access=protected)
        function result = braceReference(obj,indexOp)
            % Standard brace access

            result = obj.parenReference(indexOp);
            result = result.DataTable{:,:};

        end

        function obj = braceAssign(obj,indexOp,val)
            % Standard brace assign
            obj.DataTable.(indexOp) = val;
        end

        function n = braceListLength(obj,indexOp,indexContext)
            % Standard brace list length
            n = listLength(obj.DataTable,indexOp,indexContext);
        end
    end

    methods (Access=protected)
        function result = parenReference(obj, indexOpIn)

            indexOp = indexOpIn(1);

            % Check to see if specified column exists
            colIdx = indexOp.Indices{2};
            if ~isstring(colIdx) && ~ischar(colIdx)
                % Allow indexing past end of table
                idx = colIdx <= width(obj.DataTable);
            elseif colIdx == ":"
                % All, so always true
                idx = true;
            else
                % Allow specification by name with possible miss
                idx = ismember(colIdx, obj.DataTable.Properties.VariableNames);
            end

            % Determine data from "known" columns
            knownCols = colIdx(idx);
            if ~isempty(knownCols)
                result = obj.DataTable(:, knownCols);
            else
                result = obj.DataTable(:, []);
            end

            % Create data for unknown columns that matches the table
            if any(~idx)
                otherCols = colIdx(~idx);
                unknown = obj.makeNewColsLike(obj.DataTable, nnz(~idx));

                if isnumeric(otherCols)
                    % Other cols is e.g. a double, so create a "Var" column
                    otherCols = "Var" + otherCols;
                end

                % Ensure new columns have unique names from the known results
                otherCols = matlab.lang.makeUniqueStrings(otherCols, result.Properties.VariableNames);
                unknown.Properties.VariableNames = otherCols;

                % Add new data to existing results
                result = [result, unknown];
            end

            % Select rows - not torerant to selecting beyond the bottom of
            % the tables
            if isnumeric(indexOp.Indices{1})
                idx1 = indexOp.Indices{1};
                idx = idx1 <= height(result) & idx1 > 0;

                result = result(idx1(idx), :);
                [result(~idx, :)] = deal({missing});
                
            else
                result = result(indexOp.Indices{1}, :);
            end

            % Wrap the result in a new robust table
            result = obj.create(result);

            % Apply any subsequent access
            if numel(indexOpIn) > 1
                result = result.(indexOpIn(2:end));
            end

        end

        function obj = parenAssign(obj,indexOp,val)

            % Add rows to table if the table isn't long enought
            h = indexOp.Indices{1} - height(obj.DataTable);
            if h > 0
                obj = obj.addRows(h);
            end

            % Set the value
            obj.DataTable(indexOp) = val;

        end

        function n = parenListLength(obj,indexOp,ctx)
            if numel(indexOp) <= 2
                n = 1;
                return
            end
            containedObj = obj.DataTable(indexOp(1:2));
            n = listLength(containedObj,indexOp(3:end),ctx);
        end

        function obj = parenDelete(obj,indexOp)
            % Standard delete
            obj.DataTable.(indexOp) = [];
        end

        function result = dotReference(obj,indexOp)

            % If column exists, return as normal, otherwise return
            % "missing" column of correct length
            colName = indexOp(1).Name;
            idx = ismember(colName, obj.DataTable.Properties.VariableNames);

            if idx
                result = obj.DataTable{:, indexOp(1).Name};
            else

                % Also check dimension names
                dimNames = obj.DataTable.Properties.DimensionNames;
                idx = ismember(colName, dimNames);

                if idx
                    result = obj.DataTable.(indexOp(1));
                else
                    result = NaN(height(obj.DataTable), 1);
                end
            end

            if numel(indexOp) > 1
                result = result.(indexOp(2:end));
            end

        end

        function obj = dotAssign(obj,indexOp,rhs)
            if isempty(rhs)
                % empty rhs, so delete column

                % If column exists, remove it
                colName = indexOp(1).Name;
                idx = ismember(obj.DataTable.Properties.VariableNames, colName);

                obj.DataTable(:, idx) = [];
            elseif isa(rhs, "mlut.RTabular")
                [obj.DataTable.(indexOp)] = rhs.DataTable.Variables;
            else
                if numel(rhs) == 1
                    % Allow table.Column = 1 to set entire column to value
                    rhs = repelem(rhs, height(obj.DataTable), 1);
                end
                % Set the column as normal
                obj.DataTable.(indexOp) = rhs;
            end
        end

        function n = dotListLength(obj,indexOp,indexContext)
            n = listLength(obj.DataTable,indexOp,indexContext);
        end
    end

    methods (Access=public)
        function out = value(obj)
            out = obj.DataTable;
        end

        function out = sum(obj, varargin)
            % Pass through method for sum
            out = obj.create(sum(obj.DataTable, varargin{:}));
        end

        function out = cat(dim,varargin)
            % Allow concatenation of multiple RATs

            numCatArrays = nargin - 1;
            newArgs = cell(numCatArrays,1);

            % Get the "object" from the first argument
            obj = varargin{1};

            % Keep track of names in the tables we are concatenating so we
            % can make sure they are unique at the end
            knownNames = string.empty(1,0);
            for ix = 1:numCatArrays
                if isa(varargin{ix},'mlut.RTabular')
                    % Get the table out - means we can mix the
                    % concatenation of tables and RATs
                    tbl = varargin{ix}.DataTable;
                else
                    tbl = varargin{ix};
                end

                % if dim == 2
                %     % Horizontal concatenation, so makes sure column names
                %     % are unique
                %     tbl.Properties.VariableNames = matlab.lang.makeUniqueStrings(tbl.Properties.VariableNames, knownNames);
                % end

                % Update list of column names
                knownNames = [knownNames, string(tbl.Properties.VariableNames)]; %#ok<AGROW>

                newArgs{ix} = tbl;
            end

            if dim == 2
                % Pass through horizontal concatenation
                tbl = obj.horzcat_(newArgs{:});
            else
                % Do protected vertcat method - allows joining tables with
                % missmatched columns
                tbl = obj.vertcat_(newArgs{:});
            end

            out = obj;
            out.DataTable = tbl;
        end

        function varargout = size(obj,varargin)
            % Size is size of the internal table
            [varargout{1:nargout}] = size(obj.DataTable,varargin{:});
        end

        function obj = addRows(obj, n)
            % Add rows to the table by vertcatting with an empty table of
            % the correct length
            tbl = obj.tabularEmpty(n,0);
            new = obj.vertcat_(obj.DataTable, tbl);
            obj = obj.create(new);
        end

    end

    methods (Access = protected)

        function outTbl = horzcat_(obj, varargin)
            % Robust method to horizontally concatenating two tables which
            % may have different numbers of rows.
            if numel(varargin) > 2
                tmpTbl = obj.horzcat_(varargin{end-1}, varargin{end});
                outTbl = obj.horzcat_(varargin{1:end-2}, tmpTbl);
            elseif numel(varargin) == 1
                outTbl = varargin{1};
            elseif numel(varargin) == 0
                outTbl = obj.tabularEmpty(1,0);
            else

                tblA = varargin{1};
                tblB = varargin{2};

                hA = height(tblA);
                hB = height(tblB);

                % Remove "missing" columns if exists in other table
                aInB = ismember(tblA.Properties.VariableNames, tblB.Properties.VariableNames);
                aMissing = all(ismissing(tblA), 1);
                tblA(:, aInB & aMissing) = [];

                bInA = ismember(tblB.Properties.VariableNames, tblA.Properties.VariableNames);
                bMissing = all(ismissing(tblB), 1);
                tblB(:, bInA & bMissing) = [];

                vars = [tblA.Properties.VariableNames, tblB.Properties.VariableNames];
                key = matlab.lang.makeUniqueStrings("key", vars);
                tblA.(key) = (1:hA)';
                tblB.(key) = (1:hB)';

                outTbl = outerjoin(tblA, tblB, "Keys", key, "MergeKeys", true);
                outTbl.(key) = [];

            end

        end

        function outTbl = vertcat_(obj, varargin)
            % Robust method to vertically concatenating two tables which
            % may have missing columns.
            % Won't deal with missmatched data types
            if numel(varargin) > 2
                tmpTbl = obj.vertcat_(varargin{end-1}, varargin{end});
                outTbl = obj.vertcat_(varargin{1:end-2}, tmpTbl);
            elseif numel(varargin) == 1
                outTbl = varargin{1};
            elseif numel(varargin) == 0
                outTbl = obj.tabularEmpty(1,0);
            else
                tblA = varargin{1};
                tblB = varargin{2};

                idxRight = ~ismember(tblA.Properties.VariableNames,...
                    tblB.Properties.VariableNames);
                idxLeft = ~ismember(tblB.Properties.VariableNames,...
                    tblA.Properties.VariableNames);

                % Create a subtable of the right datatypes for the RH table
                typesA = mlut.RTabular.dataTypes(tblA);
                subTblB = obj.makeNewColsLike(tblB, nnz(idxRight), string(tblA.Properties.VariableNames(idxRight)));

                cols = string(subTblB.Properties.VariableNames);
                for j = 1:numel(cols)
                    if idxRight(j)
                        subTblB = convertvars(subTblB, cols(j), typesA(idxRight(j)));
                    end
                end

                idx = (typesA(idxRight) == "double") | (typesA(idxRight) == "single");
                subTblB(:, idx) = subTblB(:, idx) .* NaN;

                tblB = [tblB, subTblB];

                % Ditto, LH table
                typesB = mlut.RTabular.dataTypes(tblB);
                subTblA = obj.makeNewColsLike(tblA, nnz(idxLeft), string(tblB.Properties.VariableNames(idxLeft)));

                cols = string(subTblA.Properties.VariableNames);
                for j = 1:numel(cols)
                    try
                    subTblA = convertvars(subTblA, cols(j), typesB(idxLeft(j)));
                    catch
                    end
                end

                idx = (typesB(idxLeft) == "double") | (typesB(idxLeft) == "single");
                subTblA(:, idx) = subTblA(:, idx) .* NaN;

                tblA = [tblA, subTblA];

                % And vertcat
                outTbl = [tblA; tblB];
            end

        end

    end

    methods (Static)

        function types = dataTypes(tbl)
            % Allow extraction of data types independent of MATLAB version
            if verLessThan("MATLAB", "23.3")
                types = varfun(@class,tbl,'OutputFormat','cell');
                types = string(types);
            else
                types = tbl.Properties.VariableTypes;
            end
        end

    end

    methods (Static, Access = protected)

        function out = cellstring2char(in)
            out = in;
            for i = 1:numel(out)
                if class(out{i}) == "string"
                    val = cellstr(out{i});
                    if ~isempty(val)
                        out(i) = val;
                    else
                        out{i} = val;
                    end
                end
            end
        end

        function tblOut = makeNewColsLike(tbl, nCols, colNames)
            arguments
                tbl
                nCols (1,1) double
                colNames (1,:) string = string.empty()
            end

            tbl.TmpVar = NaN(height(tbl), 1);
            tmp = tbl(:, "TmpVar");
            tblOut = tmp(:, ones(nCols, 1));

            if ~isempty(colNames)
                tblOut.Properties.VariableNames = colNames;
            end
        end

    end

    methods (Abstract, Static)
        obj = empty()
    end

    methods (Abstract, Static)
        obj = create(varargin)
        tbl = tabular(varargin)
        tbl = tabularEmpty(varargin)
        tbl = array2tabular(varargin)
    end
end

