function [ROI_coords,mazeOri,ROI_bounds]=optoSortROIs(binaryimage,ROI_coords,mazeOri,ROI_bounds)
width=size(binaryimage,2);
height=size(binaryimage,1);

%% Exclude ROIs that are too far to the left or right edge of the image
minEdge=ROI_coords(:,1)<0.1*width;
maxEdge=ROI_coords(:,3)>0.93*width;
exclude=minEdge|maxEdge;
ROI_coords(exclude,:)=[];
mazeOri(exclude)=[];
ROI_bounds(exclude,:)=[];

%% Separate right-side down ROIs (0) from right to left
tmpCoords_0=ROI_coords(~mazeOri,:);
x=tmpCoords_0(:,3).^2;
[val,xSorted]=sort(x);
numColumns=mode(diff(find(diff(val)>std(diff(val))==1)));
if isnan(numColumns)
    numColumns=1;
end
if mod(length(xSorted),numColumns)~=0
    xSorted=[xSorted;ones(numColumns-mod(length(xSorted),numColumns),1)];
end

xSorted=reshape(xSorted,numColumns,floor(length(xSorted)/numColumns));

permutation_0=[];
for i=1:size(xSorted,2)
y=tmpCoords_0(xSorted(:,i),4).^2;
[~,ySorted]=sort(y);
xSorted(:,i)=xSorted(ySorted,i);
end
permutation_0=reshape(xSorted',numel(xSorted),1);

%% Separate right-side up ROIs (1) from right to left
permutation_1=[];

if sum(mazeOri)>0
tmpCoords_1=ROI_coords(mazeOri,:);
x=tmpCoords_1(:,3).^2;
[val,xSorted]=sort(x);
numColumns=mode(diff(find(diff(val)>std(diff(val))==1)));
if isnan(numColumns)
    numColumns=1;
end
if mod(length(xSorted),numColumns)~=0
    xSorted=[xSorted;ones(numColumns-mod(length(xSorted),numColumns),1)];
end

xSorted=reshape(xSorted,numColumns,floor(length(xSorted)/numColumns));

for i=1:size(xSorted,2)
y=tmpCoords_1(xSorted(:,i),4).^2;
[~,ySorted]=sort(y); 
xSorted(:,i)=xSorted(ySorted,i);
end
permutation_1=reshape(xSorted',numel(xSorted),1);
permutation_1=permutation_1+size(permutation_0,1);
ROI_coords=[tmpCoords_0;tmpCoords_1];
end

% Define master permutation vector and sort ROI_coords
permutation=[permutation_0;permutation_1];
excess=find(permutation==1);
    if length(excess)>1
        permutation(excess(2:end))=[];
    end
permutation(permutation>size(ROI_coords,1))=permutation(permutation>size(ROI_coords,1))-(max(permutation)-size(ROI_coords,1));
ROI_coords=ROI_coords(permutation,:);

% Sort mazeOri to match new ROI_coords permutation
mazeOri(1:size(permutation_0,1))=0;
mazeOri(size(permutation_0,1)+1:size(permutation,1))=1;
mazeOri=boolean(mazeOri);

end



