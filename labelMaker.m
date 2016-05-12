function out = labelMaker(labels, varargin)

%Turns labels cell array with sex, strain, treatment, maze start/end
%columns into 120x3 label cell array for Y-maze
labels
r = sum(~cellfun('isempty',labels(:,4)));
newLabel = cell(120,3);
mazeStarts=labels{:,4};
mazeEnds=labels{:,5};

for i = 1:r;
    d = mazeEnds(i) - mazeStarts(i);
    newLabel(mazeStarts(i):mazeEnds(i),1) = repmat(labels(i,1), d+1, 1);
    if isempty(labels(i,2)) == 0;
        newLabel(mazeStarts(i):mazeEnds(i),2) = repmat(labels(i,2), d+1, 1);
    end
    if isempty(labels(i,3)) == 0;
        newLabel(mazeStarts(i):mazeEnds(i),3) = repmat(labels(i,3), d+1, 1);
    end
end
out = newLabel;