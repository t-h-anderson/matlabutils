classdef DragLinkerFactory < handle
    %DRAGLINKER

    % FACTORY Singleton factory for managing drag-drop relationships.
    %
    %   The DragLinkerFactory enables components from different scopes
    %   to register as drag sources and drop targets, then automatically
    %   creates DragLinker instances when both sides are available.
    %
    %   Usage:
    %       1. Get factory instance: obj = DragLinkerFactory.make();
    %       2. Register components: addSource(name, handle)
    %                               addDestination(name, handle)
    %       3. Define relationships: addLink(srcName, dstName, ...)
    %
    %   The factory automatically creates DragLinker objects when both
    %   a source and destination are registered for a given link.
    %
    %   Example:
    %       % In different functions/scopes:
    %       DragLinkerFactory.addSource("List1", myListBox);
    %       DragLinkerFactory.addDestination("Panel1", myPanel);
    %       DragLinkerFactory.addLink("List1", "Panel1");
    %
    %   See also: DragLinker

    properties (SetAccess = private)
        Sources = dictionary(string.empty, matlab.graphics.Graphics.empty)
        Destinations = dictionary(string.empty, matlab.graphics.Graphics.empty)
        LinkFunctions = dictionary(string.empty, function_handle.empty)
        LinkUseItemGhost = dictionary(string.empty, logical.empty)
        LinkDragKeys = dictionary(string.empty, string.empty)
        DragLinkers = dictionary(string.empty, gwidgets.DragLinker.empty)
    end

    % ================================================================== %
    methods (Access = private)
        % Private constructor for singleton pattern
        function obj = DragLinkerFactory()
        end
    end

    % ================================================================== %
    methods

        function removeInvalid(obj)
            % Remove references to deleted graphics objects
            if ~isvalid(obj)
                return
            end

            % Remove invalid sources
            srcKeys = obj.Sources.keys();
            for i = 1:numel(srcKeys)
                if ~isvalid(obj.Sources(srcKeys(i)))
                    obj.Sources = remove(obj.Sources, srcKeys(i));
                end
            end

            % Remove invalid destinations
            dstKeys = obj.Destinations.keys();
            for i = 1:numel(dstKeys)
                if ~isvalid(obj.Destinations(dstKeys(i)))
                    obj.Destinations = remove(obj.Destinations, dstKeys(i));
                end
            end

            % Remove invalid drag linkers
            linkKeys = obj.DragLinkers.keys();
            for i = 1:numel(linkKeys)
                if ~isvalid(obj.DragLinkers(linkKeys(i)))
                    obj.DragLinkers = remove(obj.DragLinkers, linkKeys(i));
                end
            end
        end

        function clearDragLinkers(obj)
            % Delete all DragLinker instances and clean up invalid refs
            delete(obj.DragLinkers.values);
            obj.DragLinkers = dictionary(string.empty, gwidgets.DragLinker.empty);
            obj.removeInvalid();
        end

    end

    % ================================================================== %
    methods (Static)

        function obj = make(clearFlag)
            % Get or create the singleton factory instance
            arguments
                clearFlag (1,1) logical = false
            end

            persistent factory

            if clearFlag && ~isempty(factory) && isvalid(factory)
                delete(factory);
                factory = [];
            end

            if isempty(factory) || ~isvalid(factory)
                factory = gwidgets.internal.DragLinkerFactory();
            end

            obj = factory;
            obj.removeInvalid();
        end

        function addSource(name, src)
            % Register a drag source
            arguments
                name (1,1) string
                src (1,1) matlab.graphics.Graphics
            end

            obj = gwidgets.internal.DragLinkerFactory.make();
            obj.Sources(name) = src;
            obj.updateLinks();
        end

        function addDestination(name, dst)
            % Register a drop destination
            arguments
                name (1,1) string
                dst (1,1) matlab.graphics.Graphics
            end

            obj = gwidgets.internal.DragLinkerFactory.make();
            obj.Destinations(name) = dst;
            obj.updateLinks();
        end

        function addLink(src, dst, nvp)
            % Define a drag-drop link between named source and destination
            arguments
                src (1,1) string
                dst (1,1) string
                nvp.LinkFunction (1,1) function_handle
                nvp.DragKey (1,1) string = "control"
                nvp.UseItemGhost (1,1) logical = true
            end

            obj = gwidgets.internal.DragLinkerFactory.make();
            key = obj.makeKey(src, dst, nvp.DragKey);

            if isfield(nvp, "LinkFunction")
                obj.LinkFunctions(key) = nvp.LinkFunction;
            end

            obj.LinkUseItemGhost(key) = nvp.UseItemGhost;
            obj.LinkDragKeys(key) = nvp.DragKey;
            obj.updateLinks();
        end

        function addDragToReparentLink(src, dst, nvp)
            % Add a link that swaps the source and target parents
            arguments
                src (1,1) string
                dst (1,1) string
                nvp.DragKey (1,1) string = "alt"
            end

            obj = gwidgets.internal.DragLinkerFactory.make();
            key = obj.makeKey(src, dst, nvp.DragKey);

            obj.LinkFunctions(key) = @(s,t,p) ...
                gwidgets.internal.DragLinkerFactory.defaultReparent(s, t, p);
            obj.LinkUseItemGhost(key) = false;
            obj.LinkDragKeys(key) = nvp.DragKey;
            obj.updateLinks();
        end

        function updateLinks()
            % Create DragLinker instances for all defined links
            obj = gwidgets.internal.DragLinkerFactory.make();

            linkKeys = obj.LinkUseItemGhost.keys();
            for i = 1:numel(linkKeys)
                key = linkKeys(i);

                if obj.DragLinkers.isKey(key)
                    continue  % Already exists
                end

                [srcName, dstName, dragKey] = obj.unpackKey(key);

                hasSource = obj.Sources.isKey(srcName);
                hasDest = obj.Destinations.isKey(dstName);

                if ~hasSource || ~hasDest
                    continue
                end

                source = obj.Sources(srcName);
                destination = obj.Destinations(dstName);

                if ~isvalid(source) || ~isvalid(destination)
                    continue
                end

                % Get or create default link function
                if obj.LinkFunctions.isKey(key)
                    linkFcn = obj.LinkFunctions(key);
                else
                    linkFcn = obj.defaultFunction(source, destination);
                end

                useItemGhost = obj.LinkUseItemGhost(key);

                try
                    link = gwidgets.DragLinker(source, destination, linkFcn, ...
                        "DragKey", dragKey, ...
                        "UseItemGhost", useItemGhost);
                    obj.DragLinkers(key) = link;
                catch ME
                    warning("DragLinkerFactory:linkCreationFailed", ...
                        "Failed to create link %s → %s: %s", ...
                        srcName, dstName, ME.message);
                end
            end
        end

    end

    % ================================================================== %
    methods (Access = private)

        function key = makeKey(~, src, dst, dragKey)
            % Create unique key for source-destination-modifier combination
            key = dragKey + ":" + src + "/" + dst;
        end

        function [src, dst, dragKey] = unpackKey(~, key)
            % Extract components from a link key
            colonIdx = strfind(key, ":");
            if isempty(colonIdx)
                error("DragLinkerFactory:invalidKey", ...
                    "Key must contain ':' separator");
            end

            dragKey = extractBefore(key, ":");
            remainder = extractAfter(key, ":");

            slashIdx = strfind(remainder, "/");
            if isempty(slashIdx)
                error("DragLinkerFactory:invalidKey", ...
                    "Key must contain '/' separator");
            end

            src = extractBefore(remainder, "/");
            dst = extractAfter(remainder, "/");
        end

        function linkFcn = defaultFunction(~, source, dest)
            % Select appropriate default link function based on types
            srcType = class(source);
            dstType = class(dest);
            typeKey = srcType + "/" + dstType;

            switch typeKey
                case "matlab.ui.control.ListBox/matlab.ui.control.ListBox"
                    linkFcn = @listBox2listBox;
                case "matlab.ui.control.ListBox/matlab.ui.container.Tree"
                    linkFcn = @listBox2tree;
                case "matlab.ui.container.Tree/matlab.ui.control.ListBox"
                    linkFcn = @tree2listBox;
                case "matlab.ui.container.Tree/matlab.ui.container.Tree"
                    linkFcn = @tree2tree;
                case "matlab.ui.control.ListBox/matlab.ui.control.UIAxes"
                    linkFcn = @listBox2axes;
                case "matlab.ui.container.Tree/matlab.ui.control.UIAxes"
                    linkFcn = @tree2axes;
                otherwise
                    linkFcn = @(s,t,p) gwidgets.internal.DragLinkerFactory.defaultReparent(s,t,p);
            end
        end

    end

    % ================================================================== %
    methods (Static, Access = private)

        function defaultReparent(source, target, ~)
            % Swap parent containers and grid positions
            parent1 = source.Parent;
            parent2 = target.Parent;

            if isequal(parent1, parent2)
                % Same parent - swap grid positions if in GridLayout
                if isa(parent1, "matlab.ui.container.GridLayout")
                    col1 = source.Layout.Column;
                    row1 = source.Layout.Row;
                    col2 = target.Layout.Column;
                    row2 = target.Layout.Row;

                    source.Layout.Column = col2;
                    source.Layout.Row = row2;
                    target.Layout.Column = col1;
                    target.Layout.Row = row1;
                end
            else
                % Different parents - swap them
                if isa(parent1, "matlab.ui.container.GridLayout")
                    col1 = source.Layout.Column;
                    row1 = source.Layout.Row;
                end

                if isa(parent2, "matlab.ui.container.GridLayout")
                    col2 = target.Layout.Column;
                    row2 = target.Layout.Row;
                end

                source.Parent = parent2;
                target.Parent = parent1;

                if isa(parent2, "matlab.ui.container.GridLayout")
                    source.Layout.Column = col2;
                    source.Layout.Row = row2;
                end

                if isa(parent1, "matlab.ui.container.GridLayout")
                    target.Layout.Column = col1;
                    target.Layout.Row = row1;
                end
            end
        end

    end

end  % classdef

% ====================================================================== %
% Default Link Functions
% ====================================================================== %

function listBox2listBox(src, dst, cp)
    % Transfer selected items from source to destination listbox
    selectedVals = src.Value;
    selectedIdx = src.ValueIndex;

    % Mark selected items
    idxSrcSelected = false(1, numel(src.Items));
    idxSrcSelected(selectedIdx) = true;

    % Add placeholder to allow dropping at end
    dst.Items = [dst.Items, ""];

    % Use TestCase to simulate click at drop point
    tc = matlab.uitest.TestCase.forInteractiveUse();
    fig = ancestor(dst, "figure");
    
    % For some reason a double click is sometimes required
    tc.press(fig, cp);
    tc.press(fig, cp);

    newIdx = dst.ValueIndex;

    % Insert items at drop location
    dst.Items = [dst.Items(1:newIdx-1), selectedVals, dst.Items(newIdx:end)];
    newItems = false(1, numel(dst.Items));
    newItems = [newItems(1:newIdx-1), true(1,numel(selectedVals)), ...
                newItems(newIdx:end)];

    % Remove from source
    if isequal(src, dst)
        % Dropping on self - adjust indices
        toRemove = [idxSrcSelected(1:newIdx-1), false(1,numel(selectedVals)), ...
                    idxSrcSelected(newIdx:end)];
        src.Items(toRemove) = [];
        newItems(toRemove) = [];
    else
        src.Items(idxSrcSelected) = [];
    end

    % Remove placeholder and select new items
    dst.Items(end) = [];
    newItems(end) = [];
    tc.choose(dst, find(newItems));
end

function listBox2tree(src, dst, ~)
    % Transfer selected listbox items to tree nodes
    selectedVals = src.Value;
    selectedIdx = ismember(src.Items, selectedVals);
    src.Items(selectedIdx) = [];

    if isempty(dst.SelectedNodes)
        % Add as root nodes
        for i = 1:numel(selectedVals)
            uitreenode(dst, "Text", string(selectedVals(i)));
        end
    else
        % Add as children of selected nodes
        for j = 1:numel(dst.SelectedNodes)
            parentNode = dst.SelectedNodes(j);
            for i = 1:numel(selectedVals)
                uitreenode(parentNode, "Text", string(selectedVals(i)));
            end
        end
    end
end

function tree2listBox(src, dst, ~)
    % Transfer selected tree nodes to listbox
    nodeTexts = string({src.SelectedNodes.Text});
    delete(src.SelectedNodes);
    dst.Items = [dst.Items, nodeTexts];
end

function tree2tree(src, dst, ~)
    % Move tree nodes between trees
    selectedNodes = src.SelectedNodes;
    selectedNodes = unique(selectedNodes);
    rootNodes = getNodeTreeRoots(selectedNodes);

    if isempty(dst.SelectedNodes)
        [rootNodes.Parent] = deal(dst);
    elseif isscalar(dst.SelectedNodes)
        [rootNodes.Parent] = deal(dst.SelectedNodes);
    else
        % Multiple destinations - copy to first, duplicate to others
        [rootNodes.Parent] = deal(dst.SelectedNodes(1));
        for i = 2:numel(dst.SelectedNodes)
            copiedNodes = copy(rootNodes);
            [copiedNodes.Parent] = deal(dst.SelectedNodes(i));
        end
    end
end

function roots = getNodeTreeRoots(nodes)
    % Filter to only top-level nodes (no children in selection)
    toRemove = false(1, numel(nodes));
    for i = 1:numel(nodes)
        children = findobj(nodes(i), "Type", "uitreenode");
        children(children == nodes(i)) = [];
        toRemove = toRemove | ismember(nodes, children)';
    end
    roots = nodes(~toRemove);
end

function listBox2axes(src, dst, ~)
    % Plot selected items on axes
    selectedVals = src.Value;

    hold(dst, "on");
    for i = 1:numel(selectedVals)
        plot(dst, 1:10, randi(10, 10, 1), "DisplayName", string(selectedVals(i)));
    end
    hold(dst, "off");
    legend(dst);
end

function tree2axes(src, dst, ~)
    % Plot selected tree nodes on axes
    nodeTexts = string({src.SelectedNodes.Text});

    hold(dst, "on");
    for i = 1:numel(nodeTexts)
        plot(dst, 1:10, randi(10, 10, 1), "DisplayName", nodeTexts(i));
    end
    hold(dst, "off");
    legend(dst);
end