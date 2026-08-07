classdef SingletonFactory
    %SINGLETONFACTORY Reset singleton-managed state in selected packages.

    methods (Static)
        function reset(namespaces)
            arguments
                namespaces (1,:) string = "utils"
            end

            classNames = mlut.internal.SingletonFactory.classNames(namespaces);
            for k = 1:numel(classNames)
                makeFcn = str2func(classNames(k) + ".make");
                makeFcn(true);
            end
        end

        function names = classNames(namespaces)
            arguments
                namespaces (1,:) string = "utils"
            end

            classes = meta.class.empty(0,1);
            for namespaceName = namespaces
                namespace = matlab.metadata.Namespace.fromName(namespaceName);
                if isempty(namespace)
                    continue
                end
                classes = [classes; mlut.internal.SingletonFactory.collectClasses(namespace)]; %#ok<AGROW>
            end

            baseClass = meta.class.fromName("mlut.internal.Singleton");
            classes = classes(classes < baseClass);
            classes = classes(~[classes.Abstract]);
            names = sort(string({classes.Name}));
        end

        function classes = collectClasses(namespace)
            classes = namespace.ClassList;
            for child = namespace.InnerNamespaces(:)'
                classes = [classes; mlut.internal.SingletonFactory.collectClasses(child)]; %#ok<AGROW>
            end
        end
    end
end
