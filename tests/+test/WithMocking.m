classdef WithMocking < matlab.mock.TestCase
    
    methods (Access = protected)
        
        function verifyCalledNTimes(this,beh,n)
            
            calledNTimes = matlab.mock.constraints.WasCalled("WithCount",n);
            this.verifyThat(beh,calledNTimes)
            
        end
        
    end
    
end