classdef BaseWorkspaceManager < handle
    %BASEWORKSPACEMANAGER Access and guard base-workspace variables.

    properties (Access = private)
        Names (1,:) string = strings(1,0)
        Existed (1,:) logical = false(1,0)
        OriginalValues (1,:) cell = cell(1,0)
        IsGuardActive (1,1) logical = false
    end

    methods
        function value = evaluate(obj, expression)
            arguments
                obj (1,1) mlut.workspace.BaseWorkspaceManager
                expression (1,1) string
            end

            obj.mustBeUsable();
            [~, value] = evaluateAndCapture(mlut.workspace.BaseWorkspaceManager.baseWorkspace(), expression);
        end

        function run(obj, statement)
            arguments
                obj (1,1) mlut.workspace.BaseWorkspaceManager
                statement (1,1) string
            end

            obj.mustBeUsable();
            evalin("base", char(statement));
        end

        function names = variableNames(obj, requestedNames)
            arguments
                obj (1,1) mlut.workspace.BaseWorkspaceManager
                requestedNames (1,:) string = strings(1,0)
            end

            obj.mustBeUsable();
            workspace = mlut.workspace.BaseWorkspaceManager.baseWorkspace();

            if isempty(requestedNames)
                names = variableNames(workspace);
            else
                requestedNameArgs = cellstr(requestedNames);
                names = variableNames(workspace, requestedNameArgs{:});
            end
        end

        function info = variables(obj, requestedNames)
            arguments
                obj (1,1) mlut.workspace.BaseWorkspaceManager
                requestedNames (1,:) string = strings(1,0)
            end

            obj.mustBeUsable();
            workspace = mlut.workspace.BaseWorkspaceManager.baseWorkspace();

            if isempty(requestedNames)
                info = variables(workspace);
            else
                requestedNameArgs = cellstr(requestedNames);
                info = variables(workspace, requestedNameArgs{:});
            end
        end

        function assign(obj, name, value, nvp)
            %ASSIGN Assign a base-workspace variable and restore it on cleanup.
            arguments
                obj (1,1) mlut.workspace.BaseWorkspaceManager
                name (1,1) string
                value
                nvp.StringAs (1,1) string {mustBeMember(nvp.StringAs, ["string", "char"])} = "string"
            end

            obj.mustBeUsable();

            if nvp.StringAs == "char"
                value = char(value);
            end

            if obj.IsGuardActive
                obj.capture(name);
            else
                obj.mustBeVariableName(name);
            end

            assignin("base", char(name), value);
        end

        function capture(obj, name)
            %CAPTURE Snapshot a base-workspace variable without assigning it.
            arguments
                obj (1,1) mlut.workspace.BaseWorkspaceManager
                name (1,1) string
            end

            obj.mustBeUsable();
            obj.mustBeVariableName(name);

            if any(obj.Names == name)
                return
            end

            obj.Names(end + 1) = name;
            workspace = mlut.workspace.BaseWorkspaceManager.baseWorkspace();
            obj.Existed(end + 1) = obj.existsInWorkspace(workspace, name);

            if obj.Existed(end)
                [~, obj.OriginalValues{end + 1}] = evaluateAndCapture(workspace, name);
            else
                obj.OriginalValues{end + 1} = [];
            end
        end

        function tf = exists(obj, name)
            arguments
                obj (1,1) mlut.workspace.BaseWorkspaceManager
                name (1,1) string
            end

            obj.mustBeUsable();
            obj.mustBeVariableName(name);
            tf = obj.existsInWorkspace(mlut.workspace.BaseWorkspaceManager.baseWorkspace(), name);
        end

        function clear(obj, name)
            arguments
                obj (1,1) mlut.workspace.BaseWorkspaceManager
                name (1,1) string
            end

            obj.mustBeUsable();
            obj.mustBeVariableName(name);
            if obj.IsGuardActive
                obj.capture(name);
            end

            evalin("base", "clear('" + name + "')");
        end

        function restoreCapturedValues(obj)
            arguments
                obj (1,1) mlut.workspace.BaseWorkspaceManager
            end

            obj.mustBeUsable();

            for entryIndex = numel(obj.Names):-1:1
                obj.restoreEntry(entryIndex);
            end

            obj.resetCapturedValues();
            obj.IsGuardActive = false;
        end

        function delete(obj)
            if ~obj.IsGuardActive
                return
            end

            obj.restoreCapturedValues();
        end
    end

    methods (Static)
        function [guardCleanup, obj] = createGuard(obj)
            arguments
                obj (1,1) mlut.workspace.BaseWorkspaceManager = mlut.workspace.BaseWorkspaceManager()
            end

            obj.mustBeUsable();

            if obj.IsGuardActive
                error("mlut:workspace:guardAlreadyActive", ...
                    "Base workspace manager already has an active guard.");
            end

            obj.IsGuardActive = true;
            guardCleanup = onCleanup(@() mlut.workspace.BaseWorkspaceManager.restoreIfValid(obj));
        end
    end

    methods (Access = private)
        function mustBeUsable(obj)
            arguments
                obj (1,1) mlut.workspace.BaseWorkspaceManager
            end

            if ~isvalid(obj)
                error("mlut:workspace:invalidManager", ...
                    "Base workspace manager is no longer valid.");
            end
        end

        function resetCapturedValues(obj)
            arguments
                obj (1,1) mlut.workspace.BaseWorkspaceManager
            end

            obj.Names = strings(1,0);
            obj.Existed = false(1,0);
            obj.OriginalValues = cell(1,0);
        end

        function restoreEntry(obj, entryIndex)
            arguments
                obj (1,1) mlut.workspace.BaseWorkspaceManager
                entryIndex (1,1) double {mustBeInteger, mustBePositive}
            end

            name = obj.Names(entryIndex);

            try
                if obj.Existed(entryIndex)
                    assignin("base", char(name), obj.OriginalValues{entryIndex});
                else
                    evalin("base", "clear('" + name + "')");
                end
            catch exception
                warning("mlut:workspace:restoreFailed", ...
                    "Could not restore base-workspace variable %s: %s", ...
                    name, exception.message);
            end
        end
    end

    methods (Static, Access = private)
        function workspace = baseWorkspace()
            workspace = matlab.lang.Workspace.baseWorkspace();
        end

        function restoreIfValid(obj)
            if ~isvalid(obj)
                return
            end

            obj.restoreCapturedValues();
        end

        function tf = existsInWorkspace(workspace, name)
            arguments
                workspace (1,1) matlab.lang.Workspace
                name (1,1) string
            end

            tf = any(variableNames(workspace, name) == name);
        end

        function mustBeVariableName(name)
            arguments
                name (1,1) string
            end

            if ~isvarname(name)
                error("mlut:workspace:invalidName", ...
                    "Base-workspace variable name must be a valid MATLAB identifier: %s", name);
            end
        end
    end
end
