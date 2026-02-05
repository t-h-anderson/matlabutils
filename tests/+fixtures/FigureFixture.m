classdef FigureFixture < matlab.unittest.fixtures.Fixture
    % FigureFixture creates a figure in the property FigureHandle. The
    % figure is delete when the fixture is torn down.
    
    properties
        FigureHandle
    end
    
    properties (GetAccess = private,SetAccess = immutable)
        VisibleOnCreate (1,1) string
        Type (1,1) string = "figure"
    end
    
    methods
        
        function fixture = FigureFixture(nv)
            
            arguments
                nv.Visible (1,1) string {mustBeMember(nv.Visible,["on" "off"])} = "on"
                nv.Type (1,1) string {mustBeMember(nv.Type,["figure" "uifigure"])} = "figure"
            end
            
            fixture.VisibleOnCreate = nv.Visible;
            fixture.Type = nv.Type;
            
        end

        function setup(fixture)
            
            switch fixture.Type
                case "figure"
                	fixture.FigureHandle = figure("Visible",fixture.VisibleOnCreate);
                case "uifigure"
                    fixture.FigureHandle = uifigure("Visible",fixture.VisibleOnCreate);
            end
                    
                
            
        end
        
        function teardown(fixture)
            
            if isvalid(fixture.FigureHandle)
                delete(fixture.FigureHandle)
            end
                
        end
        
    end
    
    methods (Access = protected)
        
        function tf = isCompatible(f1,f2)
            
            % isCompatible is used by the test framework to decide whether
            % two shared fixtures are the same. We need to implement this
            % method as FigureFixture takes input arguments.
            
            tf = f1.VisibleOnCreate == f2.VisibleOnCreate;
            
        end
        
    end
    
end