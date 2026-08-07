classdef LoadStateManager

    properties
        Models (1,:) string
        DataDictionaries (1,:) string
    end

    properties (Dependent)
        IsClear (1,1) logical
    end
    
    methods
        function obj = LoadStateManager(models, dataDictionaries)
            arguments
                models (1,:) string = string.empty(1,0)
                dataDictionaries (1,:) string = string.empty(1,0)
            end

            if nargin < 1
                models = mlut.sl.Model.currentModels();
            end

            if nargin < 2
                dataDictionaries = mlut.sl.DataDictionary.current();
            end

            obj.Models = models;
            obj.DataDictionaries = dataDictionaries;
        end
        
        function [isEqual, opened, closed] = compare(obj, current)
            arguments
                obj (1,1) mlut.sl.LoadStateManager
                current (1,1) mlut.sl.LoadStateManager = createCurrentLoadState()
            end

            idxOpened = ~ismember(current.Models, obj.Models);
            idxClosed = ~ismember(obj.Models, current.Models);
            isEqual = ~any(idxOpened) && ~any(idxClosed);
            
            openedModels = current.Models(idxOpened);
            closedModels = obj.Models(idxClosed);
            
            idxOpened = ~ismember(current.DataDictionaries, obj.DataDictionaries);
            idxClosed = ~ismember(obj.DataDictionaries, current.DataDictionaries);
            isEqual = isEqual && ~any(idxOpened) && ~any(idxClosed);

            openedDataDictionaries = current.DataDictionaries(idxOpened);
            closedDataDictionaries = obj.DataDictionaries(idxClosed);

            opened = mlut.sl.LoadStateManager(openedModels, openedDataDictionaries);
            closed = mlut.sl.LoadStateManager(closedModels, closedDataDictionaries);
        end

        function restoreState(obj)
            arguments
                obj (1,1) mlut.sl.LoadStateManager
            end

            current = mlut.sl.LoadStateManager();

            [isEqual, opened, closed] = obj.compare(current);

            if isEqual
                return
            end

            for i = 1:numel(opened.Models)
                mlut.sl.Model.close(opened.Models(i));
            end

            for i = 1:numel(closed.Models)
                mlut.sl.Model.open(closed.Models(i));
            end

            current = mlut.sl.LoadStateManager();
            [isEqual, opened, closed] = obj.compare(current);

            if isEqual
                return
            end

            for i = 1:numel(opened.DataDictionaries)
                mlut.sl.DataDictionary.close(opened.DataDictionaries(i));
            end

            for i = 1:numel(closed.DataDictionaries)
                mlut.sl.DataDictionary.open(closed.DataDictionaries(i));
            end

            current = mlut.sl.LoadStateManager();
            [isEqual, ~, ~] = obj.compare(current);
            if ~isEqual
                error("mlut:sl:loadStateNotRestored", ...
                    "Could not restore the Simulink model and data dictionary load state.")
            end

        end

        function val = get.IsClear(obj)
            arguments
                obj (1,1) mlut.sl.LoadStateManager
            end

            if isempty(obj.Models) && isempty(obj.DataDictionaries)
                val = true;
            else
                val = false;
            end

        end

    end

    methods (Static)
        function openModels = getOpenModels()
            openModels = mlut.sl.Model.currentModels();
        end
           
        function openDDs = getOpenDDs()
            openDDs = mlut.sl.DataDictionary.current();
        end

        function closeAll()

            models = mlut.sl.Model.currentModels();
            for i = 1:numel(models)
                mlut.sl.Model.close(models(i));
            end

            dataDictionaries = mlut.sl.DataDictionary.current();
            for i = 1:numel(dataDictionaries)
                mlut.sl.DataDictionary.close(dataDictionaries(i));
            end
        end
    end
end

function state = createCurrentLoadState()
state = mlut.sl.LoadStateManager();
end
