
%% Display tracking to screen for tracking errors

imshow(handles.imagedata);
shg
%title('Displaying Tracking for 120s - Please check tracking and ROIs')
tic   
while  toc<handles.refTime
    
       
       % Define previous position
       lastCentroid=cenDat;
       
       % Get centroids and sort to ROIs
       imagedata=peekdata(vid,1);
       imagedata=refImage-imagedata(:,:,1);
       props=regionprops((imagedata>imageThresh),propFields);
       
       % Match centroids to ROIs by finding nearest ROI center
       cenDat=[props(:).Centroid];
       oriDat=[props(:).Orientation];
       cenDat=reshape(cenDat,2,length(cenDat)/2)';
       oriDat=reshape(oriDat,1,length(oriDat))';
       [cenDat,oriDat,centerDistance]=optoMatchCentroids2ROIs(cenDat,oriDat,centers,distanceThresh);
       lastCentroid(~isnan(cenDat))=cenDat(~isnan(cenDat));    

       %Update display
       imshow(imagedata);
       
       hold on
       % Mark centroids
       plot(cenDat(:,1),cenDat(:,2),'o','Color','r');
       % Draw rectangles to indicate ROI bounds
       for i = 1:size(ROI_coords,1)
        rectangle('Position',ROI_bounds(i,:),'EdgeColor','r')
       end
       hold off
       drawnow

end

%{
% Break KbCheck
while KbCheck
end
%}
