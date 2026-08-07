classdef Connection
    %CONNECTION Utilities for simple Simulink signal-line topology.

    methods (Static)
        function [srcBlock, srcPort] = upstreamOf(blockPath, portNum)
            arguments
                blockPath (1,1) string
                portNum (1,1) double {mustBeInteger, mustBePositive}
            end

            srcBlock = "";
            srcPort = 0;
            ph = get_param(char(blockPath), "PortHandles");
            if portNum > numel(ph.Inport)
                return
            end

            line = get_param(ph.Inport(portNum), "Line");
            if line == -1
                return
            end

            sp = get_param(line, "SrcPortHandle");
            if sp == -1
                return
            end

            srcBlock = string(get_param(sp, "Parent"));
            srcPort = get_param(sp, "PortNumber");
        end

        function [dstBlock, dstPort] = downstreamOf(blockPath, portNum)
            arguments
                blockPath (1,1) string
                portNum (1,1) double {mustBeInteger, mustBePositive}
            end

            dstBlock = string.empty(1,0);
            dstPort = zeros(1,0);
            ph = get_param(char(blockPath), "PortHandles");
            if portNum > numel(ph.Outport)
                return
            end

            line = get_param(ph.Outport(portNum), "Line");
            if line == -1
                return
            end

            dp = get_param(line, "DstPortHandle");
            dp = dp(dp ~= -1);
            if isempty(dp)
                return
            end

            dstBlock = strings(1, numel(dp));
            dstPort = zeros(1, numel(dp));
            for i = 1:numel(dp)
                dstBlock(i) = string(get_param(dp(i), "Parent"));
                dstPort(i) = get_param(dp(i), "PortNumber");
            end
        end

        function gotoBlock = gotoBlockForFrom(fromBlock)
            arguments
                fromBlock (1,1) string
            end

            gotoBlock = "";
            try
                gotoInfo = get_param(char(fromBlock), "GotoBlock");
            catch
                return
            end

            if ~isstruct(gotoInfo)
                return
            end
            if isfield(gotoInfo, "name") && string(gotoInfo.name) ~= ""
                gotoBlock = string(gotoInfo.name);
                return
            end
            if isfield(gotoInfo, "handle") && gotoInfo.handle ~= -1
                gotoBlock = string(getfullname(gotoInfo.handle));
            end
        end

        function fromBlocks = fromBlocksForGoto(gotoBlock)
            arguments
                gotoBlock (1,1) string
            end

            fromBlocks = string.empty(1,0);
            tag = string(get_param(char(gotoBlock), "GotoTag"));
            if tag == ""
                return
            end

            candidates = string(find_system(char(bdroot(char(gotoBlock))), ...
                "LookUnderMasks", "all", ...
                "BlockType", "From", ...
                "GotoTag", char(tag)));
            if isempty(candidates)
                return
            end

            gotoHandle = get_param(char(gotoBlock), "Handle");
            matches = false(size(candidates));
            for i = 1:numel(candidates)
                matches(i) = mlut.sl.Connection.fromResolvesToGoto( ...
                    candidates(i), gotoBlock, gotoHandle);
            end
            fromBlocks = candidates(matches);
        end

        function tf = isRootPortBlock(blockPath, modelName, blockType)
            arguments
                blockPath (1,1) string
                modelName (1,1) string
                blockType (1,1) string {mustBeMember(blockType, ["Inport", "Outport"])}
            end

            tf = false;
            if blockPath == ""
                return
            end
            if string(get_param(char(blockPath), "BlockType")) ~= blockType
                return
            end
            tf = string(get_param(char(blockPath), "Parent")) == modelName;
        end

        function tf = isDirectlyConnectedToRootPort(blockPath, modelName)
            arguments
                blockPath (1,1) string
                modelName (1,1) string
            end

            tf = false;
            ph = get_param(char(blockPath), "PortHandles");

            inports = ph.Inport(ph.Inport ~= -1);
            for i = 1:numel(inports)
                line = get_param(inports(i), "Line");
                if line == -1
                    continue
                end
                sp = get_param(line, "SrcPortHandle");
                if sp == -1
                    continue
                end
                srcBlock = string(get_param(sp, "Parent"));
                if mlut.sl.Connection.isRootPortBlock(srcBlock, modelName, "Inport")
                    tf = true;
                    return
                end
            end

            outports = ph.Outport(ph.Outport ~= -1);
            for i = 1:numel(outports)
                line = get_param(outports(i), "Line");
                if line == -1
                    continue
                end
                dp = get_param(line, "DstPortHandle");
                dp = dp(dp ~= -1);
                for j = 1:numel(dp)
                    dstBlock = string(get_param(dp(j), "Parent"));
                    if mlut.sl.Connection.isRootPortBlock(dstBlock, modelName, "Outport")
                        tf = true;
                        return
                    end
                end
            end
        end
    end

    methods (Static, Access = private)
        function tf = fromResolvesToGoto(fromBlock, gotoBlock, gotoHandle)
            tf = false;
            try
                gotoInfo = get_param(char(fromBlock), "GotoBlock");
            catch
                return
            end

            if ~isstruct(gotoInfo)
                return
            end
            if isfield(gotoInfo, "handle") && gotoInfo.handle == gotoHandle
                tf = true;
                return
            end
            if isfield(gotoInfo, "name") && string(gotoInfo.name) == gotoBlock
                tf = true;
            end
        end
    end
end
