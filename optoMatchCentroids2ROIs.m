function [lastCentroid,centStamp,tOriDat]=optoMatchCentroids2ROIs(cenDat,oriDat,centers,speedThresh,distanceThresh,lastCentroid,centStamp,tElapsed)

% Define placeholder data variables equal to number ROIs
tempCenDat=NaN(size(centers,1),2);
tempOriDat=NaN(size(centers,1),1);
tempCenDat(1:size(cenDat,1),:)=cenDat;
tempOriDat(1:size(oriDat,1),:)=oriDat;


% Of the remaining values, find nearest Last Known Centroid for each current centroid
tD=repmat(tempCenDat,1,1,size(lastCentroid,1));
c=repmat(lastCentroid,1,1,size(tempCenDat,1));
c=permute(c,[3 2 1]);
g=sqrt(dot((c-tD),(tD-c),2));
g=abs(g);
[lastCenDistance,j]=min(g);

% Calculate speed and distance to ROI_center for thresholding
centerDistance=abs(sqrt(dot(cenDat(j,:)'-centers',centers'-cenDat(j,:)')))';
dt=tElapsed-centStamp;
speed=squeeze(lastCenDistance)./dt;
mismatch=speed>speedThresh|centerDistance>distanceThresh;
j(mismatch)=NaN;
lastCenDistance(mismatch)=NaN;

u=unique(j(~isnan(j)));                      % Extract the unique values of the ROIs
duplicateCen=u(squeeze(histc(j,u))>1);
duplicateROIs=find(ismember(j,u(squeeze(histc(j,u))>1)));   % Find the indices of duplicate ROIs

tD=repmat(tempCenDat(duplicateCen,:),1,1,size(lastCentroid,1));
c=repmat(lastCentroid,1,1,size(tempCenDat(duplicateCen,:),1));
c=permute(c,[3 2 1]);
g=sqrt(dot((c-tD),(tD-c),2));
g=abs(g);
[~,k]=min(g,[],3);
j(duplicateROIs)=NaN;
j(k)=duplicateCen;

centStamp(~isnan(j))=tElapsed;
lastCentroid(~isnan(j),:)=cenDat(j(~isnan(j)),:);
tOriDat=NaN(size(centers,1),1);
tOriDat(~isnan(j))=oriDat(j(~isnan(j)));

end

