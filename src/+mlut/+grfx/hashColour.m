function col = hashColour(inp)
% col = hashColour(str)
% Creates a (quasi) unique colour from an input string

str = string(keyHash(inp));

if strlength(str) < 18
    str = join([repelem("0", 1, 20 - strlength(str)), str], "");
end

n1 = str2double(str{1}(1:6));
n1 = n1 / 999999;

n2 = str2double(str{1}(7:12));
n2 = n2 / 999999;

n3 = str2double(str{1}(13:18));
n3 = n3 / 999999;

col = [n1, n2, n3];

