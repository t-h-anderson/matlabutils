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

            if isa(tbl, "mlut.tabular.RTabular")
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
            result = obj.parenReference(indexOp);
            result = result.DataTable{:,:};
        end

        function obj = braceAssign(obj,indexOp,val)
            obj.DataTable.(indexOp) = val;
        end

        function n = braceListLength(obj,indexOp,indexContext)
            n = listLength(obj.DataTable,indexOp,indexContext);
        end
    end

    methods (Access=protected)
        function result = parenReference(obj, indexOpIn)

            indexOp = indexOpIn(1);

            % Build a logical mask of which requested columns exist; the
            % "robust" behaviour is to fabricate missing-valued columns
            % for any that don't.
            colIdx = indexOp.Indices{2};
            if ~isstring(colIdx) && ~ischar(colIdx)
                idx = colIdx <= width(obj.DataTable);
            elseif colIdx == ":"
                idx = true;
            else
                idx = ismember(colIdx, obj.DataTable.Properties.VariableNames);
            end

            knownCols = colIdx(idx);
            if ~isempty(knownCols)
                result = obj.DataTable(:, knownCols);
            else
                result = obj.DataTable(:, []);
            end

            if any(~idx)
                otherCols = colIdx(~idx);
                unknown = obj.makeNewColsLike(obj.DataTable, nnz(~idx));

                if isnumeric(otherCols)
                    otherCols = "Var" + otherCols;
                end

                otherCols = matlab.lang.makeUniqueStrings(otherCols, result.Properties.VariableNames);
                unknown.Properties.VariableNames = otherCols;

                result = [result, unknown];
            end

            % Numeric row indices outside the table are filled with
            % `missing` rather than erroring (the robust contract).
            if isnumeric(indexOp.Indices{1})
                idx1 = indexOp.Indices{1};
                idx = idx1 <= height(result) & idx1 > 0;

                result = result(idx1(idx), :);
                [result(~idx, :)] = deal({missing});

            else
                result = result(indexOp.Indices{1}, :);
            end

            result = obj.create(result);

            if numel(indexOpIn) > 1
                result = result.(indexOpIn(2:end));
            end

        end

        function obj = parenAssign(obj,indexOp,val)

            % Grow the underlying table when assigning past its end so
            % `t(N+k,:) = ...` succeeds rather than erroring.
            h = indexOp.Indices{1} - height(obj.DataTable);
            if h > 0
                obj = obj.addRows(h);
            end

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
            obj.DataTable.(indexOp) = [];
        end

        function result = dotReference(obj,indexOp)

            % Unknown columns yield a NaN column matching the table's
            % height instead of erroring.
            colName = indexOp(1).Name;
            idx = ismember(colName, obj.DataTable.Properties.VariableNames);

            if idx
                result = obj.DataTable{:, indexOp(1).Name};
            else
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
                colName = indexOp(1).Name;
                idx = ismember(obj.DataTable.Properties.VariableNames, colName);

                obj.DataTable(:, idx) = [];
            elseif isa(rhs, "mlut.tabular.RTabular")
                [obj.DataTable.(indexOp)] = rhs.DataTable.Variables;
            else
                if numel(rhs) == 1
                    % Broadcast a scalar across the column so
                    % `t.Column = v` mirrors built-in table semantics.
                    rhs = repelem(rhs, height(obj.DataTable), 1);
                end
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
            out = obj.create(sum(obj.DataTable, varargin{:}));
        end

        function out = cat(dim,varargin)
            % Mixed concatenation of RTabular and plain tables: unwrap
            % each argument to the underlying table, then dispatch to the
            % robust horz/vert helpers (which tolerate column mismatches).

            numCatArrays = nargin - 1;
            newArgs = cell(numCatArrays,1);

            obj = varargin{1};

            for ix = 1:numCatArrays
                if isa(varargin{ix},'mlut.tabular.RTabular')
                    tbl = varargin{ix}.DataTable;
                else
                    tbl = varargin{ix};
                end
                newArgs{ix} = tbl;
            end

            if dim == 2
                tbl = obj.horzcat_(newArgs{:});
            else
                tbl = obj.vertcat_(newArgs{:});
            end

            out = obj;
            out.DataTable = tbl;
        end

        function varargout = size(obj,varargin)
            [varargout{1:nargout}] = size(obj.DataTable,varargin{:});
        end

        function obj = addRows(obj, n)
            tbl = obj.tabularEmpty(n,0);
            new = obj.vertcat_(obj.DataTable, tbl);
            obj = obj.create(new);
        end

    end

    methods (Access = protected)

        function outTbl = horzcat_(obj, varargin)
            % Tolerates row-count mismatches by performing an outer join on
            % a synthetic key column. Drops fully-missing duplicate columns
            % to avoid clobbering real data with `missing` from the other
            % side of the join.
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
            % Tolerates column-name mismatches by padding each table with
            % the missing columns from the other side, typed to match.
            % Floating-point pads are NaN-filled; non-floating types use
            % their own missing representation. Mismatched column types
            % are not handled.
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

                typesA = mlut.tabular.RTabular.dataTypes(tblA);
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

                typesB = mlut.tabular.RTabular.dataTypes(tblB);
                subTblA = obj.makeNewColsLike(tblA, nnz(idxLeft), string(tblB.Properties.VariableNames(idxLeft)));

                cols = string(subTblA.Properties.VariableNames);
                for j = 1:numel(cols)
                    % convertvars may fail when the source/target types
                    % can't be coerced; skip those rather than aborting
                    % the whole concatenation.
                    try
                        subTblA = convertvars(subTblA, cols(j), typesB(idxLeft(j)));
                    catch
                    end
                end

                idx = (typesB(idxLeft) == "double") | (typesB(idxLeft) == "single");
                subTblA(:, idx) = subTblA(:, idx) .* NaN;

                tblA = [tblA, subTblA];

                outTbl = [tblA; tblB];
            end

        end

    end

    methods (Static)

        function types = dataTypes(tbl)
            % VariableTypes was added in R2023b (MATLAB 23.3); fall back
            % to varfun(@class,...) on older releases.
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

